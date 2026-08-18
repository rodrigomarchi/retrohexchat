defmodule RetroHexChatWeb.Components.UI.Games.SoloLobbyTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SoloLobby

  @moduletag :unit

  alias RetroHexChat.Arcade

  test "renders the lobby as a Windows-style icon launcher" do
    games = Arcade.list_games() |> Enum.take(3)

    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        games: games,
        session_status: "lobby",
        on_preview_game: "arcade_preview",
        on_close: "arcade_leave"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert [_] = Floki.find(document, ~s([data-testid="arcade-library"]))
    assert [_] = Floki.find(document, ~s([data-testid="arcade-icon-window"]))
    assert [_] = Floki.find(document, ~s([data-testid="arcade-icon-grid"]))
    assert [_] = Floki.find(document, ~s([data-testid="arcade-status-bar"]))

    for game <- games do
      assert [_] =
               Floki.find(
                 document,
                 ~s([data-testid="arcade-game-#{game.id}"][aria-label="#{game.name}"][phx-click="arcade_preview"])
               )

      assert [_] = Floki.find(document, ~s([data-testid="arcade-game-#{game.id}"] svg))
      assert text =~ game.name
    end

    assert text =~ "Ready"
    assert text =~ "WebAssembly"
    refute text =~ "Choose a game:"
    assert Floki.find(document, ~s([data-testid^="solo-game-"])) == []
  end

  test "renders the selected game preview before starting" do
    game = Arcade.list_games() |> List.first()

    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        games: Arcade.list_games(),
        session_status: "lobby",
        previewed_game: %{
          id: game.id,
          name: game.name,
          description: game.tagline,
          engine: game.engine,
          about: ["About #{game.name}"],
          controls: [{"Space", "Action"}],
          tips: ["Start from the menu"]
        },
        on_select_game: "arcade_select_game",
        on_back: "arcade_back",
        on_close: "arcade_leave"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert [_] = Floki.find(document, ~s([data-testid="arcade-game-preview"]))
    assert text =~ game.name
    assert text =~ "About #{game.name}"
    assert text =~ "Keyboard Controls"
    assert text =~ "Start from the menu"

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="solo-game-start-#{game.id}"][phx-click="arcade_select_game"])
             )

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="arcade-preview-back"][phx-click="arcade_back"])
             )
  end

  test "renders a back control while a game is running" do
    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        games: Arcade.list_games(),
        session_status: "playing",
        game_name: "DOOM",
        game_id: "doom_shareware",
        on_back_to_launcher: "arcade_back_to_launcher",
        on_close: "arcade_leave"
      )

    document = Floki.parse_document!(html)

    assert [_] = Floki.find(document, ~s([data-testid="arcade-playing-state"]))

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="arcade-back"][phx-click="arcade_back_to_launcher"])
             )

    assert [_] = Floki.find(document, ~s([data-testid="solo-session-end"]))
  end
end
