defmodule RetroHexChatWeb.Components.UI.Games.RetroGamesPanelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.RetroGamesPanel

  @moduletag :unit

  @game %{
    id: "hex_pong",
    name: "Hex Pong",
    tagline: "Cyberpunk Pong",
    description: "Pong reimagined as cyberpunk arcade.",
    icon: "game_pong",
    controls: "Arrow keys or W/S to move paddle"
  }

  test "renders the ready game with an integrated control panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@game],
        status: "ready",
        selected_game: @game,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)

    assert Floki.find(document, ~s([data-testid="retro-game-control-panel"])) != []
    assert Floki.find(document, ~s([data-testid="retro-game-sidebar-header"])) != []
    assert Floki.find(document, ~s([data-testid="retro-game-session-status"])) != []
    assert Floki.find(document, ~s([data-testid="retro-game-difficulty-panel"])) != []
    assert Floki.find(document, ~s([data-testid="retro-game-controls-panel"])) != []
    assert Floki.find(document, ~s([data-testid="retro-game-actions"])) != []

    assert Floki.find(document, ~s([data-testid="retro-game-status-label"]))
           |> Floki.text() =~ "Ready"

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="retro-game-difficulty-normal"][aria-pressed="true"])
             )

    for difficulty <- ~w(easy normal hard) do
      assert [_] =
               Floki.find(document, ~s([data-testid="retro-game-difficulty-#{difficulty}"] svg))
    end

    assert [_] = Floki.find(document, ~s([data-testid="retro-game-start-ai"]))
    assert [_] = Floki.find(document, ~s([data-testid="retro-game-back"]))
  end

  test "locks difficulty and promotes the end action while playing" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@game],
        status: "playing",
        selected_game: @game,
        difficulty: "hard",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)

    assert Floki.find(document, ~s([data-testid="retro-game-start-ai"])) == []
    assert [_] = Floki.find(document, ~s([data-testid="retro-game-end-match"]))
    assert [_] = Floki.find(document, ~s([data-testid="retro-game-difficulty-hard"][disabled]))

    assert Floki.find(document, ~s([data-testid="retro-game-status-label"]))
           |> Floki.text() =~ "Playing"
  end
end
