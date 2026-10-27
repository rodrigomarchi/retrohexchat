defmodule RetroHexChatWeb.Components.UI.Games.RetroGamesPanelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.RetroGamesPanel

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result
  alias RetroHexChatWeb.Components.UI.RetroGamesPanel

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

  @jungle %{
    id: "hex_jungle",
    name: "Hex Jungle",
    tagline: "One explorer, 255 screens",
    description: "Cross 255 screens of jungle.",
    icon: "game_jungle",
    controls: "Arrow keys or WASD to run and climb, Space to jump"
  }

  test "a one-player game is played, not played against anybody" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @jungle,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert Floki.find(document, ~s([data-testid="retro-game-start-ai"])) |> Floki.text() =~ "Play"
    refute text =~ "Play vs AI"
    refute text =~ "Solo AI"
    assert Floki.find(document, ~s([data-testid="retro-game-difficulty-panel"])) == []
    assert text =~ "32 treasures in 20 minutes"
  end

  test "a card table stands up on a narrow screen, every other game keeps its 4:3" do
    solitaire = %{@jungle | id: "hex_solitaire", name: "Hex Solitaire", icon: "game_solitaire"}

    box = fn game ->
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: game,
        difficulty: "normal",
        canvas_ready: true
      )
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="retro-game-canvas-#{game.id}"]))
      |> Floki.attribute("class")
      |> List.first()
    end

    assert box.(solitaire) =~ "aspect-[464/720]"
    assert box.(solitaire) =~ "sm:aspect-[4/3]"
    assert box.(@jungle) =~ "aspect-[4/3]"
    refute box.(@jungle) =~ "aspect-[464/720]"
  end

  test "renders the ready game with an integrated control panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @game,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)

    assert Floki.find(document, ~s([data-testid="retro-game-status-label"]))
           |> Floki.text() =~ "Ready"

    assert Floki.text(document) =~ "First to 11"

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="retro-game-difficulty-normal"][aria-pressed="true"])
             )

    assert [_] = Floki.find(document, ~s([data-testid="retro-game-start-ai"]))
    # One game per page: its home, where another is chosen, is in the chat's tab.
    assert Floki.find(document, ~s([data-testid="retro-game-back"])) == []
  end

  test "renders the Light Trails goal in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @trails,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)

    assert Floki.text(document) =~ "First to 3"
  end

  test "renders the Pixel Tanks goal and tank controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @tanks,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @outlaw,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @star_duel,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @breakout,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Clear all blocks"
    assert text =~ "Move"
  end

  test "renders the Hex Warlords goal and shield controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @warlords,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @raid,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @boxing,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @tennis,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @invaders,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "10 waves"
    assert text =~ "Move"
    assert text =~ "Fire"
    assert text =~ "Space"
  end

  test "renders the Hex Enduro goal and racing controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @enduro,
        difficulty: "normal",
        canvas_ready: true
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
        status: "ready",
        selected_game: @skiing,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "Fastest time"
    assert text =~ "Steer"
  end

  test "renders the Hex Frost goal and row-jump controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @frost,
        difficulty: "normal",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert text =~ "1 round"
    assert text =~ "Move"
    assert text =~ "Jump rows"
  end

  test "renders the Hex Hockey goal and shoot/tackle controls in the shared status panel" do
    html =
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: @hockey,
        difficulty: "normal",
        canvas_ready: true
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
        status: "playing",
        selected_game: @game,
        difficulty: "hard",
        canvas_ready: true
      )

    document = Floki.parse_document!(html)

    assert Floki.find(document, ~s([data-testid="retro-game-start-ai"])) == []
    assert [_] = Floki.find(document, ~s([data-testid="retro-game-end-match"]))
    assert [_] = Floki.find(document, ~s([data-testid="retro-game-difficulty-hard"][disabled]))

    assert Floki.find(document, ~s([data-testid="retro-game-status-label"]))
           |> Floki.text() =~ "Playing"
  end

  defp finished_text(game, result, extra \\ []) do
    [
      id: "retro-games-panel",
      status: "finished",
      selected_game: game,
      difficulty: "normal",
      canvas_ready: false,
      result: result
    ]
    |> Keyword.merge(extra)
    |> then(&render_component(fn assigns -> retro_games_panel(assigns) end, &1))
    |> Floki.parse_document!()
  end

  test "draws the score and the verdict of a finished match" do
    result = %Result{game_id: "hex_hockey", p1_score: 5, p2_score: 3, outcome: :p1}
    text = @hockey |> finished_text(result) |> Floki.text()

    assert text =~ "You 5 x 3 AI"
    assert text =~ "You won"

    result = %Result{game_id: "hex_raid", p1_score: 1200, p2_score: 1450, outcome: :p2}
    assert @raid |> finished_text(result) |> Floki.text() =~ "AI won"
  end

  test "names a co-op board and a match with no verdict in words" do
    cleared = %Result{game_id: "hex_raid", p1_score: 10, p2_score: 10, outcome: :coop_win}
    assert @raid |> finished_text(cleared) |> Floki.text() =~ "Board cleared"

    silent = %Result{game_id: "hex_raid", p1_score: 1, p2_score: 0, outcome: :none}
    assert @raid |> finished_text(silent) |> Floki.text() =~ "No winner reported"
  end

  test "a one-player game's match ends on its points alone" do
    result = %Result{game_id: "hex_jungle", p1_score: 4200, p2_score: 0, outcome: :none}
    document = finished_text(@jungle, result)
    text = Floki.text(document)

    assert text =~ "4200 points"
    refute text =~ "AI"
    refute text =~ "No winner reported"
    assert Floki.find(document, ~s([data-testid="retro-game-verdict"])) == []
  end

  test "a written match says where it went, and a personal best says so" do
    result = %Result{game_id: "hex_raid", p1_score: 1200, p2_score: 900, outcome: :p1}

    document =
      finished_text(@raid, result, record: %{personal_best: true}, ranked?: true)

    assert [_] = Floki.find(document, ~s([data-testid="retro-game-recorded"]))
    assert Floki.text(document) =~ "Personal best"

    assert [link] = Floki.find(document, ~s([data-testid="retro-game-channel-link"]))
    assert Floki.attribute(link, "href") == ["/c/hex-raid"]
    assert Floki.find(document, ~s([data-testid="retro-game-unranked"])) == []
  end

  test "a guest's match tells them how to be ranked" do
    result = %Result{game_id: "hex_raid", p1_score: 1, p2_score: 0, outcome: :p1}
    document = finished_text(@raid, result)

    assert [_] = Floki.find(document, ~s([data-testid="retro-game-unranked"]))
    assert Floki.find(document, ~s([data-testid="retro-game-recorded"])) == []

    assert [how] = Floki.find(document, ~s([data-testid="retro-game-how-to-register"]))
    assert Floki.attribute(how, "href") == ["/chat/help/nickserv"]

    # Unranked or not, the rest of the game is at its home and in its channel.
    assert [home] = Floki.find(document, ~s([data-testid="retro-game-home-link"]))
    assert Floki.attribute(home, "href") == ["/games/hex-raid"]
    assert [_] = Floki.find(document, ~s([data-testid="retro-game-channel-link"]))
  end

  test "every game in the catalogue states its own goal and keys" do
    for game <- Catalog.list_games() do
      assert is_binary(RetroGamesPanel.goal_label(game)), game.id
      assert [%{label: _, keys: [_ | _]} | _] = RetroGamesPanel.control_rows(game)
    end
  end
end
