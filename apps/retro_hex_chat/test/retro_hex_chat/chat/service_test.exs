defmodule RetroHexChat.Chat.ServiceTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.{Queries, Service}

  describe "send_message/4" do
    test "persists and returns message for valid input" do
      assert {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "Hello!")
      assert msg.channel_name == "#lobby"
      assert msg.author_nickname == "Rodrigo"
      assert msg.content == "Hello!"
      assert msg.type == "message"
    end

    test "supports custom type" do
      assert {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "does something", "action")
      assert msg.type == "action"
    end

    test "rejects empty content" do
      assert {:error, "Message cannot be empty"} = Service.send_message("#lobby", "Rodrigo", "")
    end

    test "rejects content exceeding 1000 characters" do
      long_content = String.duplicate("a", 1001)
      assert {:error, _} = Service.send_message("#lobby", "Rodrigo", long_content)
    end
  end

  describe "send_private_message/4" do
    test "persists and returns PM for valid input" do
      assert {:ok, pm} = Service.send_private_message("Alice", "Bob", "Hello PM!")
      assert pm.sender_nickname == "Alice"
      assert pm.recipient_nickname == "Bob"
      assert pm.content == "Hello PM!"
    end

    test "rejects empty content" do
      assert {:error, "Message cannot be empty"} =
               Service.send_private_message("Alice", "Bob", "")
    end

    test "rejects content exceeding 1000 characters" do
      long_content = String.duplicate("a", 1001)
      assert {:error, _} = Service.send_private_message("Alice", "Bob", long_content)
    end
  end

  describe "send_private_message with mixed-case nicks" do
    test "persists PM when sender nick starts with lowercase" do
      assert {:ok, pm} = Service.send_private_message("rod", "Troll", "Hello!")
      assert pm.sender_nickname == "rod"
      assert pm.recipient_nickname == "Troll"
    end

    test "persists PM when both nicks start with lowercase" do
      assert {:ok, pm} = Service.send_private_message("rod", "alice", "Hey")
      assert pm.sender_nickname == "rod"
      assert pm.recipient_nickname == "alice"
    end

    test "persists p2p_invite PM with lowercase sender" do
      content = "P2P session started. Join the lobby: /p2p/abc123"

      assert {:ok, pm} =
               Service.send_private_message("rod", "Troll", content, "p2p_invite")

      assert pm.type == "p2p_invite"
      assert pm.sender_nickname == "rod"

      # Verify it can be read back
      messages = Queries.list_private_messages("rod", "Troll")
      assert length(messages) == 1
      assert hd(messages).content =~ "/p2p/"
    end

    test "list_private_messages finds PMs with mixed-case nicks" do
      {:ok, _} = Service.send_private_message("rod", "Troll", "msg1")
      {:ok, _} = Service.send_private_message("Troll", "rod", "msg2")

      messages = Queries.list_private_messages("rod", "Troll")
      assert length(messages) == 2
    end

    test "list_pm_partners includes lowercase nick sender" do
      {:ok, _} = Service.send_private_message("rod", "Troll", "hi there")

      partners = Queries.list_pm_partners("Troll")
      assert Enum.any?(partners, &(&1.nickname == "rod"))
    end

    test "list_pm_partners includes lowercase nick recipient" do
      {:ok, _} = Service.send_private_message("Troll", "rod", "hi there")

      partners = Queries.list_pm_partners("rod")
      assert Enum.any?(partners, &(&1.nickname == "Troll"))
    end
  end

  describe "send_message/5 with reply" do
    test "persists message with reply fields" do
      {:ok, parent} = Service.send_message("#lobby", "Mario", "eu acho que devíamos usar Elixir")

      assert {:ok, reply} =
               Service.send_message("#lobby", "Rodrigo", "Concordo!", "message",
                 reply_to_id: parent.id
               )

      assert reply.reply_to_id == parent.id
      assert reply.reply_to_author == "Mario"
      assert reply.reply_to_preview == "eu acho que devíamos usar Elixir"
    end

    test "truncates long parent content to 100 chars in preview" do
      long_content = String.duplicate("a", 200)
      {:ok, parent} = Service.send_message("#lobby", "Mario", long_content)

      assert {:ok, reply} =
               Service.send_message("#lobby", "Rodrigo", "Reply", "message",
                 reply_to_id: parent.id
               )

      assert String.length(reply.reply_to_preview) <= 100
      assert String.ends_with?(reply.reply_to_preview, "...")
    end

    test "reply to non-existent message returns error" do
      assert {:error, _} =
               Service.send_message("#lobby", "Rodrigo", "Reply", "message", reply_to_id: 999_999)
    end

    test "reply without reply_to_id works normally" do
      assert {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "Normal message")
      assert msg.reply_to_id == nil
    end
  end

  describe "edit_message/3" do
    test "edits own message within window" do
      {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "Original")
      assert {:ok, edited} = Service.edit_message(msg.id, "Rodrigo", "Updated")
      assert edited.content == "Updated"
      assert edited.edited_at != nil
    end

    test "rejects editing another user's message" do
      {:ok, msg} = Service.send_message("#lobby", "Mario", "Mario's message")

      assert {:error, "You cannot edit other users' messages."} =
               Service.edit_message(msg.id, "Rodrigo", "Hacked")
    end

    test "rejects editing after 5-minute window" do
      {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "Old message")

      # Manually backdate inserted_at
      import Ecto.Query
      six_minutes_ago = DateTime.add(DateTime.utc_now(), -360, :second)

      RetroHexChat.Repo.update_all(
        from(m in RetroHexChat.Chat.Message, where: m.id == ^msg.id),
        set: [inserted_at: six_minutes_ago]
      )

      assert {:error, "Edit window has expired."} =
               Service.edit_message(msg.id, "Rodrigo", "Too late")
    end

    test "updates reply_to_preview in child messages on edit" do
      {:ok, parent} = Service.send_message("#lobby", "Mario", "Original content")

      {:ok, _reply} =
        Service.send_message("#lobby", "Rodrigo", "I agree", "message", reply_to_id: parent.id)

      {:ok, _} = Service.edit_message(parent.id, "Mario", "Edited content")

      updated_reply = Queries.get_reply_ids(parent.id) |> hd()
      updated = Queries.get_message(updated_reply)
      assert updated.reply_to_preview == "Edited content"
    end

    test "empty content returns error" do
      {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "Original")
      assert {:error, "Message cannot be empty"} = Service.edit_message(msg.id, "Rodrigo", "")
    end
  end

  describe "delete_message/2" do
    test "soft-deletes own message within window" do
      {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "To delete")
      assert {:ok, deleted} = Service.delete_message(msg.id, "Rodrigo")
      assert deleted.deleted_at != nil
    end

    test "rejects deleting another user's message" do
      {:ok, msg} = Service.send_message("#lobby", "Mario", "Mario's message")

      assert {:error, "You cannot delete other users' messages."} =
               Service.delete_message(msg.id, "Rodrigo")
    end

    test "rejects deleting already-deleted message" do
      {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "To delete")
      {:ok, _} = Service.delete_message(msg.id, "Rodrigo")

      assert {:error, "Message has already been deleted."} =
               Service.delete_message(msg.id, "Rodrigo")
    end
  end

  describe "send_system_message/2" do
    test "persists system message" do
      assert {:ok, msg} = Service.send_system_message("#lobby", "User joined")
      assert msg.type == "system"
      assert msg.author_nickname == "System"
    end
  end
end
