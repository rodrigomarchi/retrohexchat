defmodule RetroHexChat.Chat.SearchTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.{Queries, Search}

  defp seed_messages do
    messages = [
      %{
        channel_name: "#lobby",
        author_nickname: "Alice",
        content: "Hello world!",
        type: "message"
      },
      %{channel_name: "#lobby", author_nickname: "Bob", content: "Hi Alice!", type: "message"},
      %{
        channel_name: "#lobby",
        author_nickname: "Alice",
        content: "How are you?",
        type: "message"
      },
      %{channel_name: "#lobby", author_nickname: "Bob", content: "I am GREAT!", type: "message"},
      %{
        channel_name: "#lobby",
        author_nickname: "Charlie",
        content: "Hey everyone",
        type: "message"
      },
      %{
        channel_name: "#other",
        author_nickname: "Dave",
        content: "Hello from other",
        type: "message"
      }
    ]

    Enum.each(messages, &Queries.insert_message/1)
  end

  describe "search_messages/3" do
    test "finds matching messages by keyword" do
      seed_messages()

      results = Search.search_messages("#lobby", "Hello")
      assert length(results) == 1
      assert hd(results).content == "Hello world!"
    end

    test "case-insensitive search" do
      seed_messages()

      results = Search.search_messages("#lobby", "great")
      assert length(results) == 1
      assert hd(results).content == "I am GREAT!"
    end

    test "returns empty list when no matches" do
      seed_messages()

      assert Search.search_messages("#lobby", "nonexistent") == []
    end

    test "searches only in specified channel" do
      seed_messages()

      results = Search.search_messages("#other", "Hello")
      assert length(results) == 1
      assert hd(results).content == "Hello from other"
    end

    test "returns results ordered by id desc (most recent first)" do
      seed_messages()

      results = Search.search_messages("#lobby", "Alice")
      assert length(results) == 1
      assert hd(results).content == "Hi Alice!"
    end

    test "respects custom limit" do
      for i <- 1..10 do
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "User",
          content: "test message #{i}",
          type: "message"
        })
      end

      results = Search.search_messages("#lobby", "test message", limit: 3)
      assert length(results) == 3
    end

    test "sanitizes special LIKE characters" do
      Queries.insert_message(%{
        channel_name: "#lobby",
        author_nickname: "User",
        content: "100% done",
        type: "message"
      })

      Queries.insert_message(%{
        channel_name: "#lobby",
        author_nickname: "User",
        content: "file_name.txt",
        type: "message"
      })

      # % should be escaped - searching for "100%" should find only the exact match
      results = Search.search_messages("#lobby", "100%")
      assert length(results) == 1
      assert hd(results).content == "100% done"

      # _ should be escaped - searching for "file_name" should find only the exact match
      results = Search.search_messages("#lobby", "file_name")
      assert length(results) == 1
      assert hd(results).content == "file_name.txt"
    end
  end

  describe "count_matches/2" do
    test "returns count of matching messages" do
      seed_messages()

      assert Search.count_matches("#lobby", "Alice") == 1
    end

    test "returns 0 when no matches" do
      seed_messages()

      assert Search.count_matches("#lobby", "nonexistent") == 0
    end

    test "counts only in specified channel" do
      seed_messages()

      assert Search.count_matches("#lobby", "Hello") == 1
      assert Search.count_matches("#other", "Hello") == 1
    end
  end
end
