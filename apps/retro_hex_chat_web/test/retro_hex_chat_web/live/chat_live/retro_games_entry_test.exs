defmodule RetroHexChatWeb.ChatLive.RetroGamesEntryTest do
  @moduledoc """
  How the chat offers Retro Games, now that it does not host them.

  A catalogue is not a room: there is nothing to create and nothing to
  announce, so the chat's two entries are plain addresses opened in a tab of
  their own. What is left to assert is that both say so, and that the window
  and the child LiveView that used to be here are gone.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.DesktopLaunchers
  alias RetroHexChatWeb.Components.UI.StartMenuApp

  test "the chat renders no games window and mounts no games LiveView", %{conn: conn} do
    {:ok, view, html} = live(chat_conn(conn, "retro#{uid()}"), "/chat")

    refute html =~ ~s(data-testid="retro-games-window")
    refute html =~ ~s(data-testid="retro-games-library")
    assert live_children(view) |> Enum.all?(&(&1.module != RetroHexChatWeb.App.PlayLive))
  end

  describe "the two entries" do
    test "the Start menu links to the catalogue in a tab of its own" do
      document =
        render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
        |> Floki.parse_document!()

      assert [item] = Floki.find(document, ~s([data-testid="start-menu-item-retro-games"]))
      assert Floki.attribute(item, "href") == [Paths.play_path()]
      assert Floki.attribute(item, "target") == ["_blank"]
      assert Floki.attribute(item, "rel") == ["noopener"]
      assert Floki.attribute(item, "data-window-open") == []
    end

    test "the Games folder links to the same address" do
      document =
        render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)
        |> Floki.parse_document!()

      assert [item] = Floki.find(document, ~s([data-testid="desktop-launcher-item-retro-games"]))
      assert Floki.attribute(item, "href") == [Paths.play_path()]
      assert Floki.attribute(item, "target") == ["_blank"]
      assert Floki.attribute(item, "data-window-open") == []
    end

    test "no server event is left behind for it" do
      document =
        render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
        |> Floki.raw_html()

      refute document =~ "open_retro_games"
    end
  end
end
