defmodule RetroHexChat.Games.Catalog do
  @moduledoc """
  Registry of available P2P games.
  Each game has an id, name, description, and icon identifier.
  All games are real-time action for two players (28 games total).
  """

  use Gettext, backend: RetroHexChat.Gettext

  @type game :: %{
          id: String.t(),
          name: String.t(),
          tagline: String.t(),
          description: String.t(),
          icon: String.t(),
          controls: String.t()
        }

  @games [
    %{
      id: "hex_pong",
      name: "Hex Pong",
      tagline: gettext("Cyberpunk Pong"),
      description:
        gettext("Pong reimagined as cyberpunk arcade — neon glow, CRT scanlines, synth audio. ") <>
          gettext("First to 11 points (win by 2). Ball speeds up on each rally."),
      icon: "game_pong",
      controls: gettext("Arrow keys or W/S to move paddle")
    },
    %{
      id: "light_trails",
      name: "Light Trails",
      tagline: gettext("Don't cross the line"),
      description:
        gettext("Race across a grid arena leaving a glowing trail behind you. ") <>
          gettext("Hit a trail or the wall and you're out. Trap your opponent to win."),
      icon: "game_trails",
      controls: gettext("Arrow keys to change direction")
    },
    %{
      id: "pixel_tanks",
      name: "Pixel Tanks",
      tagline: gettext("Blast through the maze"),
      description:
        gettext("Top-down tank combat in a destructible maze. ") <>
          gettext("Shots ricochet off walls — use geometry to your advantage."),
      icon: "game_tanks",
      controls: gettext("Arrow keys (Left/Right rotate, Up forward), Space to fire")
    },
    %{
      id: "star_duel",
      name: "Star Duel",
      tagline: gettext("Dogfight in the void"),
      description:
        gettext("Newtonian space combat — thrust, rotate, and fire missiles in open vacuum. ") <>
          gettext("Wraparound edges, hyperspace warp (20% death chance), first to 7 wins."),
      icon: "game_space",
      controls: gettext("Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp")
    },
    %{
      id: "gravity_well",
      name: "Gravity Well",
      tagline: gettext("Orbit the dying star"),
      description:
        gettext("Orbital combat around a central gravity star. ") <>
          gettext(
            "Use gravity slingshots, but fly too close and the star kills you. First to 7 wins."
          ),
      icon: "game_gravity",
      controls: gettext("Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp")
    },
    %{
      id: "debris_field",
      name: "Debris Field",
      tagline: gettext("Navigate the wreckage"),
      description:
        gettext(
          "Fight through a field of floating asteroids that block missiles and kill on contact. "
        ) <>
          gettext("Use the debris for cover — or watch it destroy you. First to 7 wins."),
      icon: "game_debris",
      controls: gettext("Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp")
    },
    %{
      id: "block_breakers",
      name: "Block Breakers",
      tagline: gettext("Break blocks together"),
      description:
        gettext("Cooperative Breakout with two paddles — one at the top, one at the bottom. ") <>
          gettext("Work together to destroy all blocks before running out of lives."),
      icon: "game_breakout",
      controls: gettext("Arrow keys (Left/Right) to move paddle")
    },
    %{
      id: "hex_warlords",
      name: "Hex Warlords",
      tagline: gettext("Defend your castle"),
      description:
        gettext(
          "Versus Breakout battle — each player defends a brick castle with a king inside. "
        ) <>
          gettext(
            "Deflect or catch the fireball to smash your opponent's walls. Last king standing wins."
          ),
      icon: "game_warlords",
      controls: gettext("Arrow keys (Up/Down) to move shield, Space to catch/release fireball")
    },
    %{
      id: "hex_raid",
      name: "Hex Raid",
      tagline: gettext("Two pilots, one river"),
      description:
        gettext(
          "River Raid reimagined for two — race through a scrolling toxic canal, destroy enemies, "
        ) <>
          gettext("steal fuel, and drop mines on your rival. 10 sections of pure chaos."),
      icon: "game_raid",
      controls: gettext("Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_raid_pacifist",
      name: "Hex Raid: Pacifist",
      tagline: gettext("No mines, pure skill"),
      description:
        gettext("River Raid without sabotage — no mines allowed. ") <>
          gettext("Pure competition for points, fuel, and survival across 10 sections."),
      icon: "game_raid",
      controls: gettext("Arrow keys to move/speed, Space to fire")
    },
    %{
      id: "hex_raid_blitz",
      name: "Hex Raid: Blitz",
      tagline: gettext("Fast and furious"),
      description:
        gettext("5 sections of intense River Raid action — river starts narrow, ") <>
          gettext("fuel is scarce, mines recharge faster. Quick and chaotic."),
      icon: "game_raid",
      controls: gettext("Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_boxing",
      name: "Hex Boxing",
      tagline: gettext("Fists of fury"),
      description:
        gettext("Top-down boxing — close punches score more. ") <>
          gettext("Push-and-pull until KO or decision by points. Best of 3 rounds."),
      icon: "game_boxing",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to punch")
    },
    %{
      id: "hex_outlaw",
      name: "Hex Outlaw",
      tagline: gettext("Draw at high noon"),
      description:
        gettext("Western duel — two gunslingers and a cactus. ") <>
          gettext("Dodge bullets you can see coming. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_ricochet",
      name: "Hex Outlaw: Ricochet",
      tagline: gettext("Bullets bounce back"),
      description:
        gettext("Western duel with bouncing bullets — fire at angles to bypass the wall. ") <>
          gettext("Bullets ricochet once off ceiling/floor. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: gettext("Arrow keys or WASD to move/aim, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_stagecoach",
      name: "Hex Outlaw: Stagecoach",
      tagline: gettext("Moving cover"),
      description:
        gettext("Western duel with a stagecoach rolling across the arena. ") <>
          gettext("Time your shots around the moving obstacle. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_nml",
      name: "Hex Outlaw: No Man's Land",
      tagline: gettext("Nowhere to hide"),
      description:
        gettext("Western duel in open field — no obstacle, full horizontal movement. ") <>
          gettext("Dodge freely in your half. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_invaders",
      name: "Hex Invaders",
      tagline: gettext("Your kills are their problem"),
      description:
        gettext(
          "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. "
        ) <>
          gettext("Combos send extra. 10 waves of escalating chaos."),
      icon: "game_invaders",
      controls: gettext("Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_coop",
      name: "Hex Invaders: Co-op",
      tagline: gettext("Defend Earth together"),
      description:
        gettext("Classic co-op Space Invaders — two cannons fighting the same alien waves. ") <>
          gettext("No alien drop. Survive together or fall together."),
      icon: "game_invaders",
      controls: gettext("Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_blitz",
      name: "Hex Invaders: Blitz",
      tagline: gettext("No mercy, no delay"),
      description:
        gettext("Blitz Space Invaders — instant alien drops, easier combos, ") <>
          gettext("5 waves of pure chaos from the start."),
      icon: "game_invaders",
      controls: gettext("Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_enduro",
      name: "Hex Enduro",
      tagline: gettext("Race through the wasteland"),
      description:
        gettext("Pseudo-3D racing duel through day, snow, fog, and night. ") <>
          gettext(
            "Overtake AI cars and your opponent, manage fuel, draft in slipstreams. Best of 3 days."
          ),
      icon: "game_enduro",
      controls: gettext("Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo")
    },
    %{
      id: "hex_enduro_night",
      name: "Hex Enduro: Night Race",
      tagline: gettext("Headlights only"),
      description:
        gettext("3-minute race in permanent darkness with fog bursts. ") <>
          gettext("Pure reflexes — most overtakes wins. Headlights only visibility."),
      icon: "game_enduro",
      controls: gettext("Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo")
    },
    %{
      id: "hex_enduro_sprint",
      name: "Hex Enduro: Sprint",
      tagline: gettext("90 seconds of fury"),
      description:
        gettext("Daylight sprint — no weather changes, no fuel drain, just speed. ") <>
          gettext("90 seconds to score maximum overtakes."),
      icon: "game_enduro",
      controls: gettext("Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo")
    },
    %{
      id: "hex_tennis",
      name: "Hex Tennis",
      tagline: gettext("Serve, rally, win"),
      description:
        gettext(
          "Top-down tennis duel — automatic hitting, shot angle depends on ball contact position. "
        ) <>
          gettext("Full set with tiebreak at 6-6. Deuce, advantage, the works."),
      icon: "game_tennis",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_quick",
      name: "Hex Tennis: Quick Match",
      tagline: gettext("First to 3 games"),
      description:
        gettext("Quick tennis match — first to 3 games wins. ") <>
          gettext("Same gameplay, shorter format. No tiebreak needed."),
      icon: "game_tennis",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_sudden",
      name: "Hex Tennis: Sudden Death",
      tagline: gettext("One point, one game"),
      description:
        gettext("Every point wins a game — no 15-30-40, no deuce. ") <>
          gettext("First to 6 games takes the set. Pure pressure."),
      icon: "game_tennis",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_skiing",
      name: "Hex Skiing",
      tagline: gettext("Race the avalanche"),
      description:
        gettext("Top-down alpine descent through toxic wastelands — dodge mutant trees, ") <>
          gettext(
            "clear slalom gates, outrun the avalanche. Best of 3 runs with rising difficulty."
          ),
      icon: "game_skiing",
      controls: gettext("Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_escape",
      name: "Hex Skiing: Escape",
      tagline: gettext("Outrun the wasteland"),
      description:
        gettext("Infinite descent — the avalanche never stops accelerating. ") <>
          gettext("Last skier standing wins. Pure survival."),
      icon: "game_skiing",
      controls: gettext("Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_clean",
      name: "Hex Skiing: Clean Run",
      tagline: gettext("Pure downhill duel"),
      description:
        gettext("No avalanche, no items — just trees, rocks, and gates. ") <>
          gettext("Fastest time down the mountain wins."),
      icon: "game_skiing",
      controls: gettext("Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_frost",
      name: "Hex Frost",
      tagline: gettext("Build or be frozen"),
      description:
        gettext("Arctic construction race — jump on floating ice blocks to build your igloo. ") <>
          gettext(
            "Steal your opponent's blocks for a 2-piece swing. Best of 5 rounds with polar bears, crabs, geese, and clams."
          ),
      icon: "game_frost",
      controls: gettext("Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_blizzard",
      name: "Hex Frost: Blizzard",
      tagline: gettext("One epic round"),
      description:
        gettext("1 long round — 20-piece igloo, all enemies from the start, ") <>
          gettext("temperature drops slowly. Epic arctic endurance."),
      icon: "game_frost",
      controls: gettext("Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_peaceful",
      name: "Hex Frost: Peaceful",
      tagline: gettext("No stealing, pure race"),
      description:
        gettext("Pure construction race — no block stealing allowed. ") <>
          gettext("First to complete the igloo wins. Fair and square."),
      icon: "game_frost",
      controls: gettext("Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_hockey",
      name: "Hex Hockey",
      tagline: gettext("Neon ice warfare"),
      description:
        gettext("Top-down ice hockey in a cyberpunk arena — control your field player, ") <>
          gettext(
            "shoot, tackle, and score while your AI goalie defends. 3 periods of 2 minutes."
          ),
      icon: "game_hockey",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_blitz",
      name: "Hex Hockey: Blitz",
      tagline: gettext("Fast and brutal"),
      description:
        gettext("One period of 3 minutes — faster puck, higher tackle success rate. ") <>
          gettext("Pure intensity from start to finish."),
      icon: "game_hockey",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_showdown",
      name: "Hex Hockey: Showdown",
      tagline: gettext("First to five"),
      description:
        gettext("No timer — first to 5 goals wins. Puck speed increases with each goal scored. ") <>
          gettext("The pressure builds every time the net shakes."),
      icon: "game_hockey",
      controls: gettext("Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    }
  ]

  @spec list_games() :: [game()]
  def list_games, do: @games

  @spec get_game(String.t()) :: {:ok, game()} | {:error, :not_found}
  def get_game(id) do
    case Enum.find(@games, &(&1.id == id)) do
      nil -> {:error, :not_found}
      game -> {:ok, game}
    end
  end

  @spec valid_game_id?(String.t()) :: boolean()
  def valid_game_id?(id), do: Enum.any?(@games, &(&1.id == id))

  @spec game_ids() :: [String.t()]
  def game_ids, do: Enum.map(@games, & &1.id)
end
