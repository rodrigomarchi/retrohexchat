defmodule RetroHexChatWeb.ChatLive.EventRoutingTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  # Guards the dispatch fall-through contract during the event-routing
  # migration (docs/plans/02-chat-event-routing.md): an event that no hook in
  # @event_hook_fns claims must NOT crash the user's session — the socket is
  # returned untouched and the LiveView keeps rendering.
  describe "unrouted events" do
    test "an unknown event does not crash the session", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Router#{uid()}"), "/chat")

      assert render_hook(view, "totally_unknown_event_#{uid()}", %{"foo" => "bar"})

      # Session is still alive and interactive afterwards.
      assert Process.alive?(view.pid)
      assert render(view) =~ ~s(data-testid="chat-input-form")
    end
  end
end
