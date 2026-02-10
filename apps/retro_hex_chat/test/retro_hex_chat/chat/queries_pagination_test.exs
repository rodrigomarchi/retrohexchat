defmodule RetroHexChat.Chat.QueriesPaginationTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.Queries

  defp insert_messages(channel, count) do
    for i <- 1..count do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: "User",
          content: "Message #{i}",
          type: "message"
        })

      msg
    end
  end

  describe "list_messages/2 cursor pagination edge cases" do
    test "empty channel returns empty list" do
      assert Queries.list_messages("#empty") == []
    end

    test "exactly 50 messages returns all" do
      insert_messages("#full50", 50)

      messages = Queries.list_messages("#full50")
      assert length(messages) == 50
    end

    test "more than 50 messages returns last 50" do
      messages = insert_messages("#overflow", 60)

      result = Queries.list_messages("#overflow")
      assert length(result) == 50

      # Should contain the 50 most recent (ids 11..60 in desc order)
      oldest_returned = List.last(result)
      assert oldest_returned.id == Enum.at(messages, 10).id
    end

    test "multiple pages with before_id cursor" do
      _messages = insert_messages("#paged", 30)

      # First page: last 10
      page1 = Queries.list_messages("#paged", limit: 10)
      assert length(page1) == 10
      assert hd(page1).content == "Message 30"

      # Second page: before the oldest of page1
      oldest_page1 = List.last(page1)
      page2 = Queries.list_messages("#paged", limit: 10, before_id: oldest_page1.id)
      assert length(page2) == 10
      assert hd(page2).content == "Message 20"

      # Third page
      oldest_page2 = List.last(page2)
      page3 = Queries.list_messages("#paged", limit: 10, before_id: oldest_page2.id)
      assert length(page3) == 10
      assert hd(page3).content == "Message 10"

      # Fourth page: should be empty
      oldest_page3 = List.last(page3)
      page4 = Queries.list_messages("#paged", limit: 10, before_id: oldest_page3.id)
      assert page4 == []
    end

    test "before_id with non-existent id returns empty when no older messages" do
      insert_messages("#small", 3)

      # Use ID 1 which would be before all messages
      result = Queries.list_messages("#small", before_id: 0)
      assert result == []
    end

    test "custom limit is respected" do
      insert_messages("#limited", 20)

      result = Queries.list_messages("#limited", limit: 5)
      assert length(result) == 5
    end
  end
end
