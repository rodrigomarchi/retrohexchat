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

  @trails %{
    id: "light_trails",
    name: "Light Trails",
    tagline: "Don't cross the line",
    description: "Race across a grid arena leaving a glowing trail behind you.",
    icon: "game_trails",
    controls: "Arrow keys to change direction"
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

    assert Floki.text(document) =~ "First to 11"

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

  test "renders the Light Trails goal in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@trails],
        status: "ready",
        selected_game: @trails,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)

    assert Floki.text(document) =~ "First to 3"
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
