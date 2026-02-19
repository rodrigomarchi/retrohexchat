defmodule RetroHexChat.Chat.QueriesTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.{Message, Queries}

  describe "insert_message/1" do
    test "inserts a valid message" do
      attrs = %{
        channel_name: "#lobby",
        author_nickname: "Rodrigo",
        content: "Hello!",
        type: "message"
      }

      assert {:ok, %Message{} = msg} = Queries.insert_message(attrs)
      assert msg.channel_name == "#lobby"
      assert msg.content == "Hello!"
    end

    test "returns error for invalid attrs" do
      assert {:error, _changeset} = Queries.insert_message(%{})
    end
  end

  describe "list_messages/2" do
    test "returns messages for a channel ordered by inserted_at desc" do
      {:ok, _m1} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "User1",
          content: "First",
          type: "message"
        })

      {:ok, _m2} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "User2",
          content: "Second",
          type: "message"
        })

      {:ok, _m3} =
        Queries.insert_message(%{
          channel_name: "#other",
          author_nickname: "User3",
          content: "Other",
          type: "message"
        })

      messages = Queries.list_messages("#lobby")
      assert length(messages) == 2
      # Most recent first
      assert hd(messages).content == "Second"
    end

    test "limits to 50 messages by default" do
      for i <- 1..55 do
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "User",
          content: "Msg #{i}",
          type: "message"
        })
      end

      messages = Queries.list_messages("#lobby")
      assert length(messages) == 50
    end

    test "supports cursor-based pagination with before_id" do
      msgs =
        for i <- 1..10 do
          {:ok, msg} =
            Queries.insert_message(%{
              channel_name: "#lobby",
              author_nickname: "User",
              content: "Msg #{i}",
              type: "message"
            })

          msg
        end

      # Get messages before the 5th message (cursor)
      cursor_msg = Enum.at(msgs, 4)
      older = Queries.list_messages("#lobby", before_id: cursor_msg.id)
      assert length(older) == 4
    end
  end

  describe "get_message/1" do
    test "returns a message by ID" do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Rodrigo",
          content: "Hello!",
          type: "message"
        })

      assert %Message{id: id} = Queries.get_message(msg.id)
      assert id == msg.id
    end

    test "returns nil for non-existent ID" do
      assert nil == Queries.get_message(999_999)
    end
  end

  describe "update_message_content/3" do
    test "updates content and sets edited_at" do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Rodrigo",
          content: "Original",
          type: "message"
        })

      now = DateTime.utc_now()
      assert {:ok, updated} = Queries.update_message_content(msg, "Updated content", now)
      assert updated.content == "Updated content"
      assert updated.edited_at == now
    end
  end

  describe "soft_delete_message/2" do
    test "sets deleted_at on the message" do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Rodrigo",
          content: "To be deleted",
          type: "message"
        })

      now = DateTime.utc_now()
      assert {:ok, deleted} = Queries.soft_delete_message(msg, now)
      assert deleted.deleted_at == now
    end
  end

  describe "update_reply_previews/2" do
    test "updates reply_to_preview on all replies to a parent" do
      {:ok, parent} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Mario",
          content: "Original content",
          type: "message"
        })

      {:ok, reply} =
        Queries.insert_reply_message(%{
          channel_name: "#lobby",
          author_nickname: "Rodrigo",
          content: "I agree!",
          type: "message",
          reply_to_id: parent.id,
          reply_to_author: "Mario",
          reply_to_preview: "Original content"
        })

      assert {1, nil} = Queries.update_reply_previews(parent.id, "Edited content")

      updated_reply = Queries.get_message(reply.id)
      assert updated_reply.reply_to_preview == "Edited content"
    end
  end

  describe "list_pm_partners/2" do
    test "returns empty list when user has no PM history" do
      assert [] == Queries.list_pm_partners("NoHistory")
    end

    test "returns distinct PM partners ordered by most recent message" do
      # Alice sends PM to Bob, then to Charlie, then Bob sends back
      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "Hi Bob"
        })

      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Charlie",
          content: "Hi Charlie"
        })

      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Bob",
          recipient_nickname: "Alice",
          content: "Hi Alice back"
        })

      partners = Queries.list_pm_partners("Alice")
      nicks = Enum.map(partners, & &1.nickname)

      # Bob is most recent (last message), then Charlie
      assert nicks == ["Bob", "Charlie"]
    end

    test "includes partners where user is recipient" do
      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Dave",
          recipient_nickname: "Eve",
          content: "Hello Eve"
        })

      partners = Queries.list_pm_partners("Eve")
      assert [%{nickname: "Dave"}] = partners
    end

    test "excludes self-PMs" do
      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Frank",
          recipient_nickname: "Frank",
          content: "Note to self"
        })

      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Frank",
          recipient_nickname: "Grace",
          content: "Hi Grace"
        })

      partners = Queries.list_pm_partners("Frank")
      nicks = Enum.map(partners, & &1.nickname)
      assert nicks == ["Grace"]
      refute "Frank" in nicks
    end

    test "excludes soft-deleted messages" do
      {:ok, pm} =
        Queries.insert_private_message(%{
          sender_nickname: "Hank",
          recipient_nickname: "Ivy",
          content: "Will be deleted"
        })

      {:ok, _} = Queries.soft_delete_pm(pm, DateTime.utc_now())

      partners = Queries.list_pm_partners("Hank")
      assert [] == partners
    end

    test "limits results to 50 by default" do
      for i <- 1..55 do
        nick = "Partner#{String.pad_leading("#{i}", 3, "0")}"

        {:ok, _} =
          Queries.insert_private_message(%{
            sender_nickname: "LimitTest",
            recipient_nickname: nick,
            content: "Hi #{nick}"
          })
      end

      partners = Queries.list_pm_partners("LimitTest")
      assert length(partners) == 50
    end

    test "respects custom limit option" do
      for i <- 1..5 do
        {:ok, _} =
          Queries.insert_private_message(%{
            sender_nickname: "Custom",
            recipient_nickname: "P#{i}",
            content: "Hi P#{i}"
          })
      end

      partners = Queries.list_pm_partners("Custom", limit: 3)
      assert length(partners) == 3
    end

    test "returns last_message_at as DateTime" do
      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "TimeTest",
          recipient_nickname: "TimePartner",
          content: "Check timestamp"
        })

      [partner] = Queries.list_pm_partners("TimeTest")
      assert %DateTime{} = partner.last_message_at
    end

    test "does not return duplicate partners from bidirectional PMs" do
      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Jack",
          recipient_nickname: "Jill",
          content: "Hi"
        })

      {:ok, _} =
        Queries.insert_private_message(%{
          sender_nickname: "Jill",
          recipient_nickname: "Jack",
          content: "Hello"
        })

      partners = Queries.list_pm_partners("Jack")
      assert length(partners) == 1
      assert [%{nickname: "Jill"}] = partners
    end
  end

  describe "get_reply_ids/1" do
    test "returns IDs of messages replying to a parent" do
      {:ok, parent} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Mario",
          content: "Parent msg",
          type: "message"
        })

      {:ok, reply} =
        Queries.insert_reply_message(%{
          channel_name: "#lobby",
          author_nickname: "Rodrigo",
          content: "Reply!",
          type: "message",
          reply_to_id: parent.id,
          reply_to_author: "Mario",
          reply_to_preview: "Parent msg"
        })

      ids = Queries.get_reply_ids(parent.id)
      assert reply.id in ids
    end

    test "returns empty list when no replies exist" do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Mario",
          content: "Lonely message",
          type: "message"
        })

      assert [] = Queries.get_reply_ids(msg.id)
    end
  end
end
