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

  describe "search_messages with case_sensitive option" do
    test "case_sensitive: true matches exact case only" do
      seed_messages()

      results = Search.search_messages("#lobby", "GREAT", case_sensitive: true)
      assert length(results) == 1
      assert hd(results).content == "I am GREAT!"

      assert Search.search_messages("#lobby", "great", case_sensitive: true) == []
    end
  end

  describe "search_messages with regex option" do
    test "regex: true uses PostgreSQL regex matching" do
      seed_messages()

      results = Search.search_messages("#lobby", "Hello|Hey", regex: true)
      assert length(results) == 2
    end

    test "regex: true with case_sensitive: true" do
      seed_messages()

      results = Search.search_messages("#lobby", "hello", regex: true, case_sensitive: true)
      assert results == []

      results = Search.search_messages("#lobby", "Hello", regex: true, case_sensitive: true)
      assert length(results) == 1
    end
  end

  describe "search_messages with nick_filter option" do
    test "nick_filter limits results to specific author" do
      seed_messages()

      results = Search.search_messages("#lobby", "a", nick_filter: "Alice")
      assert Enum.all?(results, fn m -> m.author_nickname == "Alice" end)
    end

    test "nick_filter with no matching author returns empty" do
      seed_messages()

      assert Search.search_messages("#lobby", "Hello", nick_filter: "Nobody") == []
    end
  end

  describe "valid_regex?/1" do
    test "accepts valid regex patterns" do
      assert Search.valid_regex?("hello")
      assert Search.valid_regex?("error|warn")
      assert Search.valid_regex?("\\d+\\.\\d+")
      assert Search.valid_regex?("^start")
    end

    test "rejects invalid regex patterns" do
      refute Search.valid_regex?("[invalid")
      refute Search.valid_regex?("(unclosed")
      refute Search.valid_regex?("*bad")
    end
  end

  describe "search_messages history (limit/offset)" do
    test "search returns results from DB beyond visible messages" do
      for i <- 1..20 do
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "HistUser",
          content: "history test msg #{i}",
          type: "message"
        })
      end

      # Default limit 50 returns all 20
      results = Search.search_messages("#lobby", "history test")
      assert length(results) == 20

      # With limit 5, returns only 5 most recent
      results = Search.search_messages("#lobby", "history test", limit: 5)
      assert length(results) == 5
    end
  end

  describe "count_matches/3" do
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

    test "respects filter options" do
      seed_messages()

      # Alice wrote "Hello world!" and "How are you?" — only "How are you?" contains "a"
      assert Search.count_matches("#lobby", "a", nick_filter: "Alice") == 1
      assert Search.count_matches("#lobby", "GREAT", case_sensitive: true) == 1
    end
  end
end
