defmodule RetroHexChatWeb.ChatLive.EventRoutingTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.PubSub

  # Guards the dispatch fall-through contract: an event that no hook in
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

  describe "system nuke broadcasts" do
    test "globally force-disconnect connected chat sessions", %{conn: conn} do
      nick = "NukeRoute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      _ = :sys.get_state(view.pid)
      assert Tracker.online?("channel:#lobby", nick)

      Phoenix.PubSub.broadcast(
        PubSub,
        "server:settings",
        {:system_nuked,
         %{
           force_disconnect: true,
           reason: "system-reset",
           system_nuke: true,
           skip_whowas: true
         }}
      )

      assert_push_event(view, "intentional_disconnect", %{}, 1_000)
      refute Tracker.online?("channel:#lobby", nick)
      assert_redirect(view, "/chat/session/clear?reason=system-reset")
    end
  end
end
