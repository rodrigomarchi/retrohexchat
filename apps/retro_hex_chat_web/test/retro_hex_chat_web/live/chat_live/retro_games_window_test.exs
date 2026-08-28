defmodule RetroHexChatWeb.ChatLive.RetroGamesWindowTest do
  @moduledoc """
  The chat's Retro Games window, now that it hosts a child LiveView.

  The window used to hold a LiveComponent and a host adapter that opened it.
  Both are gone: the window body is `App.PlayLive`, the same module `/play`
  serves, and opening the window needs no server round trip because the child
  loads its own catalogue in its own mount. What is left to assert is that the
  chat still renders it, and that it is still always mounted — a hidden window
  whose child unmounted would take the canvas hook with it.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChatWeb.Components.UI.StartMenuApp

  test "the chat renders the window with the games LiveView inside", %{conn: conn} do
    {:ok, _view, html} = live(chat_conn(conn, "retro#{uid()}"), "/chat")

    assert html =~ ~s(data-testid="retro-games-window")
    assert html =~ ~s(data-testid="retro-games-library")
  end

  # The window is hidden, not unmounted. A child LiveView that only rendered
  # while the window was open would restart its match every time someone
  # minimised it.
  test "the games LiveView is mounted even though the window starts closed", %{conn: conn} do
    {:ok, view, _html} = live(chat_conn(conn, "retrm#{uid()}"), "/chat")

    assert [_child] = live_children(view)
  end

  describe "opening it" do
    # No `open_retro_games` server event any more: the entries carry
    # `data-window-open`, which the window manager acts on client-side.
    test "the Start menu opens the window client-side" do
      document =
        render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
        |> Floki.parse_document!()

      assert [item] = Floki.find(document, ~s([data-testid="start-menu-item-retro-games"]))
      assert Floki.attribute(item, "data-window-open") == ["retro-games"]
    end

    test "no server event is left behind for it" do
      document =
        render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
        |> Floki.raw_html()

      refute document =~ "open_retro_games"
    end
  end
end
