defmodule RetroHexChat.Chat.QueriesPmTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.{PrivateMessage, Queries}

  describe "insert_private_message/1" do
    test "inserts a valid private message" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Bob",
        content: "Hello Bob!",
        type: "message"
      }

      assert {:ok, %PrivateMessage{} = pm} = Queries.insert_private_message(attrs)
      assert pm.sender_nickname == "Alice"
      assert pm.recipient_nickname == "Bob"
      assert pm.content == "Hello Bob!"
      assert pm.type == "message"
    end

    test "returns error for invalid attrs" do
      assert {:error, _changeset} = Queries.insert_private_message(%{})
    end

    test "defaults type to message" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Bob",
        content: "Hi!"
      }

      assert {:ok, %PrivateMessage{type: "message"}} = Queries.insert_private_message(attrs)
    end
  end

  describe "list_private_messages/2" do
    test "returns messages for a conversation ordered by id desc" do
      {:ok, _pm1} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "First"
        })

      {:ok, _pm2} =
        Queries.insert_private_message(%{
          sender_nickname: "Bob",
          recipient_nickname: "Alice",
          content: "Second"
        })

      messages = Queries.list_private_messages("Alice", "Bob")
      assert length(messages) == 2
      # Most recent first
      assert hd(messages).content == "Second"
    end

    test "returns messages regardless of sender/recipient order" do
      {:ok, _pm1} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "Hello"
        })

      # Query with reversed order should still find the message
      messages_ab = Queries.list_private_messages("Alice", "Bob")
      messages_ba = Queries.list_private_messages("Bob", "Alice")

      assert length(messages_ab) == 1
      assert length(messages_ba) == 1
      assert hd(messages_ab).id == hd(messages_ba).id
    end

    test "does not return messages from other conversations" do
      {:ok, _pm1} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "For Bob"
        })

      {:ok, _pm2} =
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Charlie",
          content: "For Charlie"
        })

      messages = Queries.list_private_messages("Alice", "Bob")
      assert length(messages) == 1
      assert hd(messages).content == "For Bob"
    end

    test "limits to 50 messages by default" do
      for i <- 1..55 do
        Queries.insert_private_message(%{
          sender_nickname: "Alice",
          recipient_nickname: "Bob",
          content: "Msg #{i}"
        })
      end

      messages = Queries.list_private_messages("Alice", "Bob")
      assert length(messages) == 50
    end

    test "supports cursor-based pagination with before_id" do
      pms =
        for i <- 1..10 do
          {:ok, pm} =
            Queries.insert_private_message(%{
              sender_nickname: "Alice",
              recipient_nickname: "Bob",
              content: "Msg #{i}"
            })

          pm
        end

      cursor_pm = Enum.at(pms, 4)
      older = Queries.list_private_messages("Alice", "Bob", before_id: cursor_pm.id)
      assert length(older) == 4
    end
  end
end
