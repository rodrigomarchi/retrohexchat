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
      assert Search.count_matches("#lobby", "Hi", mention_nick: "Alice") == 1
      assert Search.count_matches("#lobby", "GREAT", case_sensitive: true) == 1
    end
  end
end
