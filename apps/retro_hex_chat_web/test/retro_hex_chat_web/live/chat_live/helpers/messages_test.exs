defmodule RetroHexChatWeb.ChatLive.Helpers.MessagesTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.ChatLive.Helpers.Channel
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  describe "stream_type/1" do
    test "keeps renderable persisted message types" do
      assert Messages.stream_type("message") == :message
      assert Messages.stream_type("action") == :action
      assert Messages.stream_type("p2p_invite") == :p2p_invite
      assert Messages.stream_type(:notice) == :notice
    end

    test "falls back for removed or unknown persisted message types" do
      assert Messages.stream_type("space_invite") == :message
      assert Messages.stream_type(:space_invite) == :message
      assert Messages.stream_type("future_type") == :message
      assert Messages.stream_type(nil) == :message
    end
  end

  test "channel stream items tolerate legacy space invite rows" do
    msg = %{
      id: 1,
      author_nickname: "Reginald",
      content: "Legacy invite",
      type: "space_invite",
      inserted_at: ~U[2026-07-08 12:00:00Z]
    }

    assert %{type: :message, content: "Legacy invite", content_format: "irc"} =
             Channel.message_to_stream_item(msg)
  end

  test "channel stream items keep persisted content format" do
    msg = %{
      id: 2,
      author_nickname: "Ada",
      content: "**Markdown**",
      content_format: "markdown",
      type: "message",
      inserted_at: ~U[2026-07-08 12:00:00Z]
    }

    assert %{content_format: "markdown"} = Channel.message_to_stream_item(msg)
  end

  test "channel stream items keep persisted visible text when present" do
    msg = %{
      id: 3,
      author_nickname: "Ada",
      content: "**Markdown**",
      content_format: "markdown",
      plain_content: "Markdown",
      type: "message",
      inserted_at: ~U[2026-07-08 12:00:00Z]
    }

    assert %{plain_content: "Markdown"} = Channel.message_to_stream_item(msg)
  end
end
