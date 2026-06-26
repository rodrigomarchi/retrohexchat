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
end
