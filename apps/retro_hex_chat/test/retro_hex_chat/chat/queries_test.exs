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
end
