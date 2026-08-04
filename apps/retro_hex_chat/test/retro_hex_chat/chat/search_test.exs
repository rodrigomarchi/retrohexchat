defmodule RetroHexChat.Chat.SearchTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.{Message, Queries, Search}
  alias RetroHexChat.Repo

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

    test "searches Markdown messages by visible text, not source markup" do
      {:ok, _msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Ada",
          content: "**release** [doc](https://example.com/runbook)",
          content_format: "markdown",
          type: "message"
        })

      assert Search.count_matches("#lobby", "release") == 1
      assert Search.count_matches("#lobby", "release doc", regex: false) == 1
      assert Search.count_matches("#lobby", "release\\s+doc", regex: true) == 1
      assert Search.count_matches("#lobby", "**release**") == 0
      assert Search.count_matches("#lobby", "runbook") == 0
    end

    test "mention filter uses visible text instead of hidden Markdown URL text" do
      {:ok, _msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Ada",
          content: "please read [notes](https://example.com/Alice)",
          content_format: "markdown",
          type: "message"
        })

      assert Search.count_matches("#lobby", "please", mention_nick: "notes") == 1
      assert Search.count_matches("#lobby", "please", mention_nick: "Alice") == 0
    end

    test "falls back to raw content for legacy rows without plain_content" do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Legacy",
          content: "**legacy**",
          content_format: "markdown",
          type: "message"
        })

      Repo.update_all(Message, set: [plain_content: nil])

      assert msg.plain_content == "legacy"
      assert Search.count_matches("#lobby", "**legacy**") == 1
    end
  end
end
