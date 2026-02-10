defmodule RetroHexChatWeb.Components.ChatMessageTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ChatMessage

  @base_message %{
    id: "msg-1",
    author: "alice",
    content: "Hello world",
    type: :message,
    timestamp: ~U[2026-01-15 14:30:00Z]
  }

  describe "chat_message/1" do
    test "renders regular message with nick and content" do
      html = render_component(&ChatMessage.chat_message/1, message: @base_message)
      assert html =~ "chat-nick"
      assert html =~ "alice"
      assert html =~ "Hello world"
      assert html =~ "chat-content"
    end

    test "renders action message" do
      msg = %{@base_message | type: :action}
      html = render_component(&ChatMessage.chat_message/1, message: msg)
      assert html =~ "chat-action"
      assert html =~ "* alice Hello world"
    end

    test "renders system message" do
      msg = %{@base_message | type: :system}
      html = render_component(&ChatMessage.chat_message/1, message: msg)
      assert html =~ "chat-system"
      assert html =~ "* Hello world"
    end

    test "renders service message" do
      msg = %{@base_message | type: :service}
      html = render_component(&ChatMessage.chat_message/1, message: msg)
      assert html =~ "chat-service"
      assert html =~ "Hello world"
    end

    test "renders error message" do
      msg = %{@base_message | type: :error}
      html = render_component(&ChatMessage.chat_message/1, message: msg)
      assert html =~ "chat-error"
      assert html =~ "Hello world"
    end

    test "renders timestamp in [HH:MM] format" do
      html = render_component(&ChatMessage.chat_message/1, message: @base_message)
      assert html =~ "[14:30]"
      assert html =~ "chat-timestamp"
    end

    test "nick color is deterministic per nick" do
      html1 = render_component(&ChatMessage.chat_message/1, message: @base_message)
      html2 = render_component(&ChatMessage.chat_message/1, message: @base_message)
      # Extract color from style attribute - both renders should produce same color
      assert html1 == html2
    end
  end
end
