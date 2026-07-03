defmodule RetroHexChatWeb.Components.UI.ChatMessageTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChatMessage

  @moduletag :unit

  defp render_message(type) do
    render_component(&chat_message/1,
      type: type,
      nick: "alice",
      inner_block: %{
        inner_block: fn _, _ -> "hello" end
      }
    )
  end

  describe "chat_message/1 type styling" do
    test "renders a notify_rename system message without crashing" do
      # Regression: a nick change broadcasts a :notify_rename message. A missing
      # type_class/1 clause used to raise FunctionClauseError, crashing the chat
      # LiveView and reloading every connected client.
      html = render_message("notify_rename")
      assert html =~ "text-notice"
      assert html =~ "hello"
    end

    test "renders an unknown message type plainly instead of crashing" do
      # The catch-all guarantees one unexpected type can never take down the
      # whole channel's LiveView.
      html = render_message("some_future_type")
      assert html =~ "hello"
    end

    test "still styles known types" do
      assert render_message("error") =~ "text-error"
      assert render_message("notify_online") =~ "text-success"
    end
  end

  describe "chat_message/1 meta column" do
    test "renders an interactive .chat-nick handle without angle brackets" do
      html =
        render_component(&chat_message/1,
          type: "normal",
          nick: "alice",
          inner_block: %{inner_block: fn _, _ -> "hi" end}
        )

      assert html =~ ~s(class="chat-nick)
      assert html =~ ~s(data-nick="alice")
      assert html =~ "alice"
      refute html =~ "&lt;alice&gt;"
    end

    test "renders a non-interactive .chat-source origin with no data-nick" do
      html =
        render_component(&chat_message/1,
          type: "system",
          source: "System",
          inner_block: %{inner_block: fn _, _ -> "joined" end}
        )

      assert html =~ ~s(class="chat-source)
      assert html =~ "System"
      refute html =~ "data-nick"
    end

    test "keeps the timestamp testid and carries the full datetime in the title" do
      html =
        render_component(&chat_message/1,
          type: "normal",
          nick: "bob",
          timestamp: "01/01 12:00",
          meta_title: "01/01/2024 12:00",
          inner_block: %{inner_block: fn _, _ -> "hi" end}
        )

      assert html =~ ~s(data-testid="chat-message-timestamp")
      assert html =~ "01/01 12:00"
      assert html =~ ~s(title="01/01/2024 12:00")
    end
  end
end
