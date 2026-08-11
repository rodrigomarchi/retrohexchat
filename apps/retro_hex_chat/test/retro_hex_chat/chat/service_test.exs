defmodule RetroHexChat.Chat.ServiceTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.{Attachments, Queries, Service, UploadedFile}
  alias RetroHexChat.Topics

  defp unique_channel do
    "#svc-#{System.unique_integer([:positive])}"
  end

  defp unique_nick(prefix) do
    "#{prefix}#{System.unique_integer([:positive])}"
  end

  defp prepare_uploaded_file(owner, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          filename: "report.pdf",
          content_type: "application/pdf",
          byte_size: 42
        },
        attrs
      )

    {:ok, file, _meta} = Attachments.prepare_direct_upload(owner, attrs)
    {:ok, [file]} = Attachments.confirm_uploaded_files([file.id], owner)
    file
  end

  describe "send_message/4" do
    test "persists and returns message for valid input" do
      assert {:ok, msg} = Service.send_message("#lobby", "Alice", "Hello!")
      assert msg.channel_name == "#lobby"
      assert msg.author_nickname == "Alice"
      assert msg.content == "Hello!"
      assert msg.type == "message"
    end

    test "supports custom type" do
      assert {:ok, msg} = Service.send_message("#lobby", "Alice", "does something", "action")
      assert msg.type == "action"
    end

    test "rejects empty content" do
      assert {:error, "Message cannot be empty"} = Service.send_message("#lobby", "Alice", "")
    end

    test "rejects content exceeding 1000 characters" do
      long_content = String.duplicate("a", 1001)
      assert {:error, _} = Service.send_message("#lobby", "Alice", long_content)
    end

    test "persists markdown format with visible plain text" do
      assert {:ok, msg} =
               Service.send_message(
                 unique_channel(),
                 "Alice",
                 "**Hello** [doc](https://example.com)",
                 "message",
                 content_format: "markdown"
               )

      assert msg.content_format == "markdown"
      assert msg.plain_content == "Hello doc"
    end

    test "broadcasts content format for channel messages" do
      channel = unique_channel()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      assert {:ok, msg} =
               Service.send_message(channel, "Alice", "**Hello**", "message",
                 content_format: "markdown"
               )

      assert_receive %{
        event: "new_message",
        payload: %{id: id, content_format: "markdown"}
      }

      assert id == msg.id
    end

    test "persists a file-only message and broadcasts attachment metadata" do
      channel = unique_channel()
      owner = unique_nick("A")
      file = prepare_uploaded_file(owner)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      assert {:ok, msg} =
               Service.send_message(channel, owner, "", "message", attachment_ids: [file.id])

      assert msg.content == ""
      assert [%{file: attached_file} = attachment] = msg.attachments
      assert attached_file.id == file.id
      assert attachment.display_filename == "report.pdf"

      assert %UploadedFile{status: "attached"} = Repo.get!(UploadedFile, file.id)

      assert_receive %{
        event: "new_message",
        payload: %{
          id: id,
          attachments: [
            %{
              file_id: file_id,
              filename: "report.pdf",
              content_type: "application/pdf",
              byte_size: 42,
              logical_path: logical_path
            }
          ]
        }
      }

      assert id == msg.id
      assert file_id == file.id
      assert logical_path =~ "report.pdf"
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

    # One delivery each, carrying the whole message. It used to take two
    # broadcasts in two shapes to say this, and the one that reached everybody
    # carried half the fields.
    test "delivers the whole message to both people, once each" do
      sender = unique_nick("A")
      recipient = unique_nick("B")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(sender))
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(recipient))

      assert {:ok, pm} = Service.send_private_message(sender, recipient, "Hello PM!")

      assert_receive %{
        event: "new_pm",
        payload: %{
          id: written_id,
          sender: ^sender,
          recipient: ^recipient,
          content: "Hello PM!",
          type: :message,
          peer: ^recipient,
          direction: :outgoing,
          attachments: [],
          reply_to_id: nil
        }
      }

      assert_receive %{
        event: "new_pm",
        payload: %{id: read_id, peer: ^sender, direction: :incoming, content: "Hello PM!"}
      }

      assert written_id == pm.id
      assert read_id == pm.id
      refute_receive %{event: "new_pm"}
    end

    # A private conversation has no topic of its own any more: it is two
    # inboxes, and nothing is published anywhere a third party could be waiting.
    test "publishes nothing on a topic named after the pair" do
      sender = unique_nick("A")
      recipient = unique_nick("B")

      Phoenix.PubSub.subscribe(
        RetroHexChat.PubSub,
        "pm:" <> Enum.join(Enum.sort([sender, recipient]), ":")
      )

      assert {:ok, pm} = Service.send_private_message(sender, recipient, "Hello PM!")
      assert {:ok, _edited} = Service.edit_private_message(pm.id, sender, "Edited")
      assert {:ok, _deleted} = Service.delete_private_message(pm.id, sender)

      refute_receive _anything
    end

    test "delivers non-default private message types the same way" do
      sender = unique_nick("A")
      recipient = unique_nick("B")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(recipient))

      assert {:ok, pm} = Service.send_private_message(sender, recipient, "waves", "action")

      assert_receive %{
        event: "new_pm",
        payload: %{id: id, peer: ^sender, type: :action, direction: :incoming}
      }

      assert id == pm.id
    end

    test "persists and broadcasts markdown format for PMs" do
      sender = unique_nick("A")
      recipient = unique_nick("B")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(recipient))

      assert {:ok, pm} =
               Service.send_private_message(
                 sender,
                 recipient,
                 "**Hello** [doc](https://example.com)",
                 "message",
                 content_format: "markdown"
               )

      assert pm.content_format == "markdown"
      assert pm.plain_content == "Hello doc"

      assert_receive %{
        event: "new_pm",
        payload: %{id: id, content_format: "markdown"}
      }

      assert id == pm.id
    end

    test "persists a private message with an attachment" do
      sender = unique_nick("A")
      recipient = unique_nick("B")
      file = prepare_uploaded_file(sender, %{filename: "private.txt", content_type: "text/plain"})
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(recipient))

      assert {:ok, pm} =
               Service.send_private_message(sender, recipient, "see file", "message",
                 attachment_ids: [file.id]
               )

      assert [%{file: attached_file} = attachment] = pm.attachments
      assert attached_file.id == file.id
      assert attachment.display_filename == "private.txt"

      assert_receive %{
        event: "new_pm",
        payload: %{
          id: id,
          attachments: [%{file_id: file_id, filename: "private.txt"}]
        }
      }

      assert id == pm.id
      assert file_id == file.id
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
      messages = Queries.list_private_messages("rod", "Troll").items
      assert length(messages) == 1
      assert hd(messages).content =~ "/p2p/"
    end

    test "list_private_messages finds PMs with mixed-case nicks" do
      {:ok, _} = Service.send_private_message("rod", "Troll", "msg1")
      {:ok, _} = Service.send_private_message("Troll", "rod", "msg2")

      messages = Queries.list_private_messages("rod", "Troll").items
      assert length(messages) == 2
    end

    test "list_pm_partners includes lowercase nick sender" do
      {:ok, _} = Service.send_private_message("rod", "Troll", "hi there")

      partners = Queries.list_pm_partners("Troll").items
      assert Enum.any?(partners, &(&1.nickname == "rod"))
    end

    test "list_pm_partners includes lowercase nick recipient" do
      {:ok, _} = Service.send_private_message("Troll", "rod", "hi there")

      partners = Queries.list_pm_partners("rod").items
      assert Enum.any?(partners, &(&1.nickname == "Troll"))
    end
  end

  describe "send_private_message/5 with reply" do
    test "uses visible text for markdown parent preview" do
      {:ok, parent} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "**Original** [doc](https://example.com)",
          content_format: "markdown"
        })

      assert {:ok, reply} =
               Service.send_private_message("Bob", "Alice", "Reply", "message",
                 reply_to_id: parent.id
               )

      assert reply.reply_to_preview == "Original doc"
    end
  end

  describe "edit_private_message/3" do
    test "broadcasts the persisted content format on PM edit" do
      sender = unique_nick("A")
      recipient = unique_nick("B")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(recipient))

      {:ok, pm} =
        Queries.insert_private_message(%{
          sender_nickname: sender,
          recipient_nickname: recipient,
          content: "**Original**",
          content_format: "markdown"
        })

      assert {:ok, updated} = Service.edit_private_message(pm.id, sender, "**Edited**")
      assert updated.content_format == "markdown"
      assert updated.plain_content == "Edited"

      assert_receive %{
        event: "message_edited",
        payload: %{id: id, content_format: "markdown"}
      }

      assert id == pm.id
    end

    test "can explicitly change PM format on edit" do
      sender = unique_nick("A")
      recipient = unique_nick("B")
      {:ok, pm} = Service.send_private_message(sender, recipient, "Original")

      assert {:ok, updated} =
               Service.edit_private_message(pm.id, sender, "**Edited**",
                 content_format: "markdown"
               )

      assert updated.content == "**Edited**"
      assert updated.content_format == "markdown"
      assert updated.plain_content == "Edited"
    end

    test "updates reply_to_preview with visible markdown text on edit" do
      {:ok, parent} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "**Original**",
          content_format: "markdown"
        })

      {:ok, reply} =
        Service.send_private_message("Bob", "Alice", "I agree", "message", reply_to_id: parent.id)

      {:ok, _} =
        Service.edit_private_message(parent.id, "Alice", "**Edited** [doc](https://e.com)")

      updated = Queries.get_private_message(reply.id)
      assert updated.reply_to_preview == "Edited doc"
    end
  end

  describe "send_message/5 with reply" do
    test "persists message with reply fields" do
      {:ok, parent} = Service.send_message("#lobby", "Mario", "eu acho que devíamos usar Elixir")

      assert {:ok, reply} =
               Service.send_message("#lobby", "Alice", "Concordo!", "message",
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
               Service.send_message("#lobby", "Alice", "Reply", "message", reply_to_id: parent.id)

      assert String.length(reply.reply_to_preview) <= 100
      assert String.ends_with?(reply.reply_to_preview, "...")
    end

    test "uses visible text for markdown parent preview" do
      {:ok, parent} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Mario",
          content: "**Original** [doc](https://example.com)",
          content_format: "markdown"
        })

      assert {:ok, reply} =
               Service.send_message("#lobby", "Alice", "Reply", "message", reply_to_id: parent.id)

      assert reply.reply_to_preview == "Original doc"
    end

    test "reply to non-existent message returns error" do
      assert {:error, _} =
               Service.send_message("#lobby", "Alice", "Reply", "message", reply_to_id: 999_999)
    end

    test "reply without reply_to_id works normally" do
      assert {:ok, msg} = Service.send_message("#lobby", "Alice", "Normal message")
      assert msg.reply_to_id == nil
    end
  end

  describe "edit_message/3" do
    test "broadcasts the persisted content format on channel edit" do
      channel = unique_channel()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: "Alice",
          content: "**Original**",
          content_format: "markdown"
        })

      assert {:ok, updated} = Service.edit_message(msg.id, "Alice", "**Edited**")
      assert updated.content_format == "markdown"
      assert updated.plain_content == "Edited"

      assert_receive %{
        event: "message_edited",
        payload: %{id: id, content_format: "markdown"}
      }

      assert id == msg.id
    end

    test "can explicitly change channel message format on edit" do
      {:ok, msg} = Service.send_message(unique_channel(), "Alice", "Original")

      assert {:ok, updated} =
               Service.edit_message(msg.id, "Alice", "**Edited**", content_format: "markdown")

      assert updated.content == "**Edited**"
      assert updated.content_format == "markdown"
      assert updated.plain_content == "Edited"
    end

    test "edits own message within window" do
      {:ok, msg} = Service.send_message("#lobby", "Alice", "Original")
      assert {:ok, edited} = Service.edit_message(msg.id, "Alice", "Updated")
      assert edited.content == "Updated"
      assert edited.edited_at != nil
    end

    test "rejects editing another user's message" do
      {:ok, msg} = Service.send_message("#lobby", "Mario", "Mario's message")

      assert {:error, "You cannot edit other users' messages."} =
               Service.edit_message(msg.id, "Alice", "Hacked")
    end

    test "rejects editing after 5-minute window" do
      {:ok, msg} = Service.send_message("#lobby", "Alice", "Old message")

      # Manually backdate inserted_at
      import Ecto.Query
      six_minutes_ago = DateTime.add(DateTime.utc_now(), -360, :second)

      RetroHexChat.Repo.update_all(
        from(m in RetroHexChat.Chat.Message, where: m.id == ^msg.id),
        set: [inserted_at: six_minutes_ago]
      )

      assert {:error, "Edit window has expired."} =
               Service.edit_message(msg.id, "Alice", "Too late")
    end

    test "updates reply_to_preview in child messages on edit" do
      {:ok, parent} = Service.send_message("#lobby", "Mario", "Original content")

      {:ok, _reply} =
        Service.send_message("#lobby", "Alice", "I agree", "message", reply_to_id: parent.id)

      {:ok, _} = Service.edit_message(parent.id, "Mario", "Edited content")

      updated_reply = Queries.reply_ids(parent) |> hd()
      updated = Queries.get_message(updated_reply)
      assert updated.reply_to_preview == "Edited content"
    end

    test "updates reply_to_preview with visible markdown text on edit" do
      {:ok, parent} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Mario",
          content: "**Original**",
          content_format: "markdown"
        })

      {:ok, _reply} =
        Service.send_message("#lobby", "Alice", "I agree", "message", reply_to_id: parent.id)

      {:ok, _} = Service.edit_message(parent.id, "Mario", "**Edited** [doc](https://example.com)")

      updated_reply = Queries.reply_ids(parent) |> hd()
      updated = Queries.get_message(updated_reply)
      assert updated.reply_to_preview == "Edited doc"
    end

    test "empty content returns error" do
      {:ok, msg} = Service.send_message("#lobby", "Alice", "Original")
      assert {:error, "Message cannot be empty"} = Service.edit_message(msg.id, "Alice", "")
    end
  end

  describe "delete_message/2" do
    test "soft-deletes own message within window" do
      {:ok, msg} = Service.send_message("#lobby", "Alice", "To delete")
      assert {:ok, deleted} = Service.delete_message(msg.id, "Alice")
      assert deleted.deleted_at != nil
    end

    test "rejects deleting another user's message" do
      {:ok, msg} = Service.send_message("#lobby", "Mario", "Mario's message")

      assert {:error, "You cannot delete other users' messages."} =
               Service.delete_message(msg.id, "Alice")
    end

    test "rejects deleting already-deleted message" do
      {:ok, msg} = Service.send_message("#lobby", "Alice", "To delete")
      {:ok, _} = Service.delete_message(msg.id, "Alice")

      assert {:error, "Message has already been deleted."} =
               Service.delete_message(msg.id, "Alice")
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
