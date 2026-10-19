defmodule RetroHexChatWeb.ChatLive.RetroGamesEntryTest do
  @moduledoc """
  How the chat offers Retro Games, now that it does not host them.

  A catalogue is not a room: there is nothing to create and nothing to
  announce. What the chat keeps is the catalogue — the Games folder holds a
  game per game, its modes chosen on the game's home, which each icon opens
  over the chat. The game itself opens from there, in a tab of its own. The
  Start menu carries the way to that folder and not a second copy of it.

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
    {:ok, view, html} = live(chat_conn(conn, "retro#{uid()}"), "/")

    refute html =~ ~s(data-testid="retro-games-window")
    refute html =~ ~s(data-testid="retro-games-library")
    assert live_children(view) |> Enum.all?(&(&1.module != RetroHexChatWeb.App.PlayLive))
  end

  describe "the catalogue" do
    test "the Games folder holds a game per game, each opening its home" do
      document = render_launcher()

      for game <- Catalog.base_games() do
        assert [item] =
                 Floki.find(document, ~s([data-testid="desktop-launcher-item-game-#{game.id}"])),
               "the Games folder is missing #{game.id}"

        assert Floki.attribute(item, "href") == [Paths.game_page_path(game.id)]
        assert Floki.attribute(item, "data-phx-link") == ["patch"]
        assert Floki.attribute(item, "target") == []
      end

      # A mode is chosen on its game's home, not from a second icon.
      for mode <- Catalog.modes_of("hex_tennis") do
        assert Floki.find(document, ~s([data-testid="desktop-launcher-item-game-#{mode.id}"])) ==
                 []
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
