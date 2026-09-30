defmodule RetroHexChatWeb.ChatLive.RetroGamesEntryTest do
  @moduledoc """
  How the chat offers Retro Games, now that it does not host them.

  A catalogue is not a room: there is nothing to create and nothing to
  announce, so a game is a plain address opened in a tab of its own. What the
  chat keeps is the catalogue — the Games folder holds a game per game, so the
  second tab is offered on the game the reader chose rather than on the list
  they are still reading. The Start menu carries the way to that folder and not
  a second copy of it.

  What is left to assert is that the folder is complete, that each row says
  where it goes, that nothing opens a tab on the bare catalogue any more, and
  that the window and the child LiveView that used to be here are still gone.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.DesktopLaunchers
  alias RetroHexChatWeb.Components.UI.StartMenuApp

  test "the chat renders no games window and mounts no games LiveView", %{conn: conn} do
    {:ok, view, html} = live(chat_conn(conn, "retro#{uid()}"), "/chat")

    refute html =~ ~s(data-testid="retro-games-window")
    refute html =~ ~s(data-testid="retro-games-library")
    assert live_children(view) |> Enum.all?(&(&1.module != RetroHexChatWeb.App.PlayLive))
  end

  describe "the catalogue" do
    test "the Games folder holds a game per game, each at its own address" do
      document = render_launcher()

      for game <- Catalog.list_solo_games() do
        assert [item] =
                 Floki.find(document, ~s([data-testid="desktop-launcher-item-game-#{game.id}"])),
               "the Games folder is missing #{game.id}"

        assert Floki.attribute(item, "href") == [Paths.play_path(game.id)]
        assert Floki.attribute(item, "target") == ["_blank"]
        assert Floki.attribute(item, "rel") == ["noopener"]
        assert Floki.attribute(item, "data-confirm-tab") == ["surface"]
        assert Floki.attribute(item, "data-confirm-label") == [game.name]
        assert Floki.attribute(item, "data-window-open") == []
      end
    end

    test "the Start menu opens that folder rather than carrying a second copy" do
      document = render_start_menu()

      assert [item] = Floki.find(document, ~s([data-testid="start-menu-item-retro-games"]))
      assert Floki.attribute(item, "data-window-open") == ["desktop-launcher-games"]
      assert Floki.attribute(item, "href") == []

      refute Floki.raw_html(document) =~ "start-menu-item-game-"
    end

    test "neither entry opens a tab on the bare catalogue any more" do
      for document <- [render_launcher(), render_start_menu()] do
        refute Paths.play_path() in Floki.attribute(document, "a", "href")
      end
    end

    test "no server event is left behind for it" do
      refute Floki.raw_html(render_start_menu()) =~ "open_retro_games"
    end
  end

  defp render_launcher do
    render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)
    |> Floki.parse_document!()
  end

  defp render_start_menu do
    render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
    |> Floki.parse_document!()
  end
end
