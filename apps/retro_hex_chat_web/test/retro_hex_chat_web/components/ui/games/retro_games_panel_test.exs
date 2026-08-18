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

  @tanks %{
    id: "pixel_tanks",
    name: "Pixel Tanks",
    tagline: "Blast through the maze",
    description: "Top-down tank combat in a destructible maze.",
    icon: "game_tanks",
    controls: "Arrow keys rotate/advance, Space or Shift to fire"
  }

  @outlaw %{
    id: "hex_outlaw_ricochet",
    name: "Hex Outlaw: Ricochet",
    tagline: "Bullets bounce back",
    description: "Western duel with bouncing bullets.",
    icon: "game_outlaw",
    controls: "Arrow keys or WASD to move/aim, Space or Shift to fire"
  }

  @star_duel %{
    id: "star_duel",
    name: "Star Duel",
    tagline: "Dogfight in the void",
    description: "Newtonian space combat in open vacuum.",
    icon: "game_space",
    controls: "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
  }

  @breakout %{
    id: "block_breakers",
    name: "Block Breakers",
    tagline: "Break blocks together",
    description: "Cooperative Breakout with two paddles.",
    icon: "game_breakout",
    controls: "Arrow keys (Left/Right) to move paddle"
  }

  @warlords %{
    id: "hex_warlords",
    name: "Hex Warlords",
    tagline: "Defend your castle",
    description: "Versus Breakout battle.",
    icon: "game_warlords",
    controls: "Arrow keys (Up/Down) to move shield, Space to catch/release fireball"
  }

  @raid %{
    id: "hex_raid_blitz",
    name: "Hex Raid: Blitz",
    tagline: "Fast and furious",
    description: "5 sections of intense River Raid action.",
    icon: "game_raid",
    controls: "Arrow keys to move/speed, Space to fire, Shift to drop mine"
  }

  @boxing %{
    id: "hex_boxing",
    name: "Hex Boxing",
    tagline: "Fists of fury",
    description: "Top-down boxing in a cyberpunk ring.",
    icon: "game_boxing",
    controls: "Arrow keys or WASD to move, Space or Shift to punch"
  }

  @tennis %{
    id: "hex_tennis",
    name: "Hex Tennis",
    tagline: "Serve, rally, win",
    description: "Top-down tennis duel.",
    icon: "game_tennis",
    controls: "Arrow keys or WASD to move, Space or Shift to serve"
  }

  @invaders %{
    id: "hex_invaders",
    name: "Hex Invaders",
    tagline: "Your kills are their problem",
    description: "Split-screen Space Invaders.",
    icon: "game_invaders",
    controls: "Arrow keys or A/D to move, Space to fire"
  }

  @enduro %{
    id: "hex_enduro_sprint",
    name: "Hex Enduro: Sprint",
    tagline: "90 seconds of fury",
    description: "Daylight sprint with no fuel drain.",
    icon: "game_enduro",
    controls: "Arrow keys lane/speed, Space or Shift for turbo"
  }

  @skiing %{
    id: "hex_skiing_clean",
    name: "Hex Skiing: Clean Run",
    tagline: "Pure downhill duel",
    description: "Fastest time down the mountain wins.",
    icon: "game_skiing",
    controls: "Arrow keys (left/right) or A/D to steer"
  }

  @frost %{
    id: "hex_frost_blizzard",
    name: "Hex Frost: Blizzard",
    tagline: "One epic round",
    description: "1 long round with all enemies from the start.",
    icon: "game_frost",
    controls: "Arrow keys or WASD to move, Up/Down to jump between rows"
  }

  @hockey %{
    id: "hex_hockey_showdown",
    name: "Hex Hockey: Showdown",
    tagline: "First to five",
    description: "No timer. First to five goals wins.",
    icon: "game_hockey",
    controls: "Arrow keys or WASD to move, Space or Shift to shoot/tackle"
  }

  test "renders the library as a Windows-style icon launcher" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@game, @tanks, @hockey],
        status: "library",
        selected_game: nil,
        difficulty: "normal",
        canvas_ready: false,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert [_] = Floki.find(document, ~s([data-testid="retro-games-library"]))
    assert [_] = Floki.find(document, ~s([data-testid="retro-games-icon-window"]))
    assert [_] = Floki.find(document, ~s([data-testid="retro-games-icon-grid"]))
    assert [_] = Floki.find(document, ~s([data-testid="retro-games-status-bar"]))

    for game <- [@game, @tanks, @hockey] do
      assert [_] =
               Floki.find(
                 document,
                 ~s([data-testid="retro-game-#{game.id}"][aria-label="#{game.name}"])
               )

      assert [_] = Floki.find(document, ~s([data-testid="retro-game-#{game.id}"] svg))
      assert text =~ game.name
    end

    assert text =~ "Ready"
    assert text =~ "Solo AI"
    refute text =~ "Arrow keys"
    refute text =~ "Browser-native games"
  end

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

  test "renders the Pixel Tanks goal and tank controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@tanks],
        status: "ready",
        selected_game: @tanks,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Best of 3"
    assert text =~ "Rotate"
    assert text =~ "Forward"
    assert text =~ "Fire"
    assert text =~ "Space"
    assert text =~ "Shift"
  end

  test "renders the Hex Outlaw goal and fire controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@outlaw],
        status: "ready",
        selected_game: @outlaw,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Best of 3"
    assert text =~ "Move/Aim"
    assert text =~ "Fire"
    assert text =~ "Space"
    assert text =~ "Shift"
  end

  test "renders the Star Duel goal and space combat controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@star_duel],
        status: "ready",
        selected_game: @star_duel,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "First to 7"
    assert text =~ "Rotate"
    assert text =~ "Thrust"
    assert text =~ "Fire/Warp"
    assert text =~ "Space"
  end

  test "renders the Block Breakers goal and paddle controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@breakout],
        status: "ready",
        selected_game: @breakout,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Clear all blocks"
    assert text =~ "Move"
    assert text =~ "A"
    assert text =~ "D"
  end

  test "renders the Hex Warlords goal and shield controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@warlords],
        status: "ready",
        selected_game: @warlords,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Last king standing"
    assert text =~ "Shield"
    assert text =~ "Catch/Release"
    assert text =~ "Space"
  end

  test "renders the Hex Raid goal and mine controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@raid],
        status: "ready",
        selected_game: @raid,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "5 sections"
    assert text =~ "Move/Speed"
    assert text =~ "Fire/Mine"
    assert text =~ "Space"
    assert text =~ "Shift"
  end

  test "renders the Hex Boxing goal and punch controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@boxing],
        status: "ready",
        selected_game: @boxing,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Best of 3"
    assert text =~ "Move"
    assert text =~ "Punch"
    assert text =~ "Space"
    assert text =~ "Shift"
  end

  test "renders the Hex Tennis goal and serve controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@tennis],
        status: "ready",
        selected_game: @tennis,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "First to 6"
    assert text =~ "Move"
    assert text =~ "Serve"
    assert text =~ "Space"
    assert text =~ "Shift"
  end

  test "renders the Hex Invaders goal and fire controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@invaders],
        status: "ready",
        selected_game: @invaders,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "10 waves"
    assert text =~ "Move"
    assert text =~ "Fire"
    assert text =~ "Space"
    assert text =~ "A"
    assert text =~ "D"
  end

  test "renders the Hex Enduro goal and racing controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@enduro],
        status: "ready",
        selected_game: @enduro,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "90 seconds"
    assert text =~ "Lane"
    assert text =~ "Speed"
    assert text =~ "Turbo"
    assert text =~ "Space"
    assert text =~ "Shift"
  end

  test "renders the Hex Skiing goal and steering controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@skiing],
        status: "ready",
        selected_game: @skiing,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Fastest time"
    assert text =~ "Steer"
    assert text =~ "A"
    assert text =~ "D"
  end

  test "renders the Hex Frost goal and row-jump controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@frost],
        status: "ready",
        selected_game: @frost,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "1 round"
    assert text =~ "Move"
    assert text =~ "Jump rows"
    assert text =~ "W"
    assert text =~ "S"
  end

  test "renders the Hex Hockey goal and shoot/tackle controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@hockey],
        status: "ready",
        selected_game: @hockey,
        difficulty: "normal",
        canvas_ready: true,
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "First to 5 goals"
    assert text =~ "Move"
    assert text =~ "Shoot/Tackle"
    assert text =~ "Space"
    assert text =~ "Shift"
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

  test "renders Hockey-style flat final score payloads" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@hockey],
        status: "finished",
        selected_game: @hockey,
        difficulty: "normal",
        canvas_ready: false,
        result: %{"winner" => "p1", "score_p1" => 5, "score_p2" => 3},
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "You 5 x 3 AI"
    assert text =~ "You won"
  end

  test "renders Raid-style flat final score payloads" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        games: [@raid],
        status: "finished",
        selected_game: @raid,
        difficulty: "normal",
        canvas_ready: false,
        result: %{"winner" => 2, "score1" => 1200, "score2" => 1450},
        target: "retro-games-island"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "You 1200 x 1450 AI"
    assert text =~ "AI won"
  end
end
