defmodule RetroHexChatWeb.HoverOfflineNickTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  test "hovering a nick with no presence meta does not crash the LiveView", %{conn: conn} do
    {:ok, view, _html} = live(chat_conn(conn, "HovSafe#{uid()}"), "/chat")

    # An offline/stale nick from message history has nil presence meta; the
    # hover card must render with unknown client fields instead of raising
    # (a missing :browser key used to crash the whole session).
    render_hook(view, "nick_hover", %{"nick" => "GhostNick#{uid()}", "x" => 100, "y" => 100})

    assert Process.alive?(view.pid)
    assert render(view)
  end
end
