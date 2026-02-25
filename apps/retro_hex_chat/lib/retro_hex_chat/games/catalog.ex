defmodule RetroHexChat.Games.Catalog do
  @moduledoc """
  Registry of available P2P games.
  Each game has an id, name, description, and icon identifier.
  All games are real-time action for two players (28 games total).
  """

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
      tagline: "Cyberpunk Pong",
      description:
        "Pong reimagined as cyberpunk arcade — neon glow, CRT scanlines, synth audio. " <>
          "First to 11 points (win by 2). Ball speeds up on each rally.",
      icon: "game_pong",
      controls: "Arrow keys or W/S to move paddle"
    },
    %{
      id: "light_trails",
      name: "Light Trails",
      tagline: "Don't cross the line",
      description:
        "Race across a grid arena leaving a glowing trail behind you. " <>
          "Hit a trail or the wall and you're out. Trap your opponent to win.",
      icon: "game_trails",
      controls: "Arrow keys to change direction"
    },
    %{
      id: "pixel_tanks",
      name: "Pixel Tanks",
      tagline: "Blast through the maze",
      description:
        "Top-down tank combat in a destructible maze. " <>
          "Shots ricochet off walls — use geometry to your advantage.",
      icon: "game_tanks",
      controls: "Arrow keys (Left/Right rotate, Up forward), Space to fire"
    },
    %{
      id: "star_duel",
      name: "Star Duel",
      tagline: "Dogfight in the void",
      description:
        "Newtonian space combat — thrust, rotate, and fire missiles in open vacuum. " <>
          "Wraparound edges, hyperspace warp (20% death chance), first to 7 wins.",
      icon: "game_space",
      controls: "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
    },
    %{
      id: "gravity_well",
      name: "Gravity Well",
      tagline: "Orbit the dying star",
      description:
        "Orbital combat around a central gravity star. " <>
          "Use gravity slingshots, but fly too close and the star kills you. First to 7 wins.",
      icon: "game_gravity",
      controls: "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
    },
    %{
      id: "debris_field",
      name: "Debris Field",
      tagline: "Navigate the wreckage",
      description:
        "Fight through a field of floating asteroids that block missiles and kill on contact. " <>
          "Use the debris for cover — or watch it destroy you. First to 7 wins.",
      icon: "game_debris",
      controls: "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
    },
    %{
      id: "block_breakers",
      name: "Block Breakers",
      tagline: "Break blocks together",
      description:
        "Cooperative Breakout with two paddles — one at the top, one at the bottom. " <>
          "Work together to destroy all blocks before running out of lives.",
      icon: "game_breakout",
      controls: "Arrow keys (Left/Right) to move paddle"
    },
    %{
      id: "hex_warlords",
      name: "Hex Warlords",
      tagline: "Defend your castle",
      description:
        "Versus Breakout battle — each player defends a brick castle with a king inside. " <>
          "Deflect or catch the fireball to smash your opponent's walls. Last king standing wins.",
      icon: "game_warlords",
      controls: "Arrow keys (Up/Down) to move shield, Space to catch/release fireball"
    },
    %{
      id: "hex_raid",
      name: "Hex Raid",
      tagline: "Two pilots, one river",
      description:
        "River Raid reimagined for two — race through a scrolling toxic canal, destroy enemies, " <>
          "steal fuel, and drop mines on your rival. 10 sections of pure chaos.",
      icon: "game_raid",
      controls: "Arrow keys to move/speed, Space to fire, Shift to drop mine"
    },
    %{
      id: "hex_raid_pacifist",
      name: "Hex Raid: Pacifist",
      tagline: "No mines, pure skill",
      description:
        "River Raid without sabotage — no mines allowed. " <>
          "Pure competition for points, fuel, and survival across 10 sections.",
      icon: "game_raid",
      controls: "Arrow keys to move/speed, Space to fire"
    },
    %{
      id: "hex_raid_blitz",
      name: "Hex Raid: Blitz",
      tagline: "Fast and furious",
      description:
        "5 sections of intense River Raid action — river starts narrow, " <>
          "fuel is scarce, mines recharge faster. Quick and chaotic.",
      icon: "game_raid",
      controls: "Arrow keys to move/speed, Space to fire, Shift to drop mine"
    },
    %{
      id: "hex_boxing",
      name: "Hex Boxing",
      tagline: "Fists of fury",
      description:
        "Top-down boxing — close punches score more. " <>
          "Push-and-pull until KO or decision by points. Best of 3 rounds.",
      icon: "game_boxing",
      controls: "Arrow keys or WASD to move, Space or Shift to punch"
    },
    %{
      id: "hex_outlaw",
      name: "Hex Outlaw",
      tagline: "Draw at high noon",
      description:
        "Western duel — two gunslingers and a cactus. " <>
          "Dodge bullets you can see coming. First to 10. Best of 3 rounds.",
      icon: "game_outlaw",
      controls: "Arrow keys or WASD to move, Space or Shift to fire"
    },
    %{
      id: "hex_outlaw_ricochet",
      name: "Hex Outlaw: Ricochet",
      tagline: "Bullets bounce back",
      description:
        "Western duel with bouncing bullets — fire at angles to bypass the wall. " <>
          "Bullets ricochet once off ceiling/floor. First to 10. Best of 3 rounds.",
      icon: "game_outlaw",
      controls: "Arrow keys or WASD to move/aim, Space or Shift to fire"
    },
    %{
      id: "hex_outlaw_stagecoach",
      name: "Hex Outlaw: Stagecoach",
      tagline: "Moving cover",
      description:
        "Western duel with a stagecoach rolling across the arena. " <>
          "Time your shots around the moving obstacle. First to 10. Best of 3 rounds.",
      icon: "game_outlaw",
      controls: "Arrow keys or WASD to move, Space or Shift to fire"
    },
    %{
      id: "hex_outlaw_nml",
      name: "Hex Outlaw: No Man's Land",
      tagline: "Nowhere to hide",
      description:
        "Western duel in open field — no obstacle, full horizontal movement. " <>
          "Dodge freely in your half. First to 10. Best of 3 rounds.",
      icon: "game_outlaw",
      controls: "Arrow keys or WASD to move, Space or Shift to fire"
    },
    %{
      id: "hex_invaders",
      name: "Hex Invaders",
      tagline: "Your kills are their problem",
      description:
        "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. " <>
          "Combos send extra. 10 waves of escalating chaos.",
      icon: "game_invaders",
      controls: "Arrow keys or A/D to move, Space to fire"
    },
    %{
      id: "hex_invaders_coop",
      name: "Hex Invaders: Co-op",
      tagline: "Defend Earth together",
      description:
        "Classic co-op Space Invaders — two cannons fighting the same alien waves. " <>
          "No alien drop. Survive together or fall together.",
      icon: "game_invaders",
      controls: "Arrow keys or A/D to move, Space to fire"
    },
    %{
      id: "hex_invaders_blitz",
      name: "Hex Invaders: Blitz",
      tagline: "No mercy, no delay",
      description:
        "Blitz Space Invaders — instant alien drops, easier combos, " <>
          "5 waves of pure chaos from the start.",
      icon: "game_invaders",
      controls: "Arrow keys or A/D to move, Space to fire"
    },
    %{
      id: "hex_enduro",
      name: "Hex Enduro",
      tagline: "Race through the wasteland",
      description:
        "Pseudo-3D racing duel through day, snow, fog, and night. " <>
          "Overtake AI cars and your opponent, manage fuel, draft in slipstreams. Best of 3 days.",
      icon: "game_enduro",
      controls: "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
    },
    %{
      id: "hex_enduro_night",
      name: "Hex Enduro: Night Race",
      tagline: "Headlights only",
      description:
        "3-minute race in permanent darkness with fog bursts. " <>
          "Pure reflexes — most overtakes wins. Headlights only visibility.",
      icon: "game_enduro",
      controls: "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
    },
    %{
      id: "hex_enduro_sprint",
      name: "Hex Enduro: Sprint",
      tagline: "90 seconds of fury",
      description:
        "Daylight sprint — no weather changes, no fuel drain, just speed. " <>
          "90 seconds to score maximum overtakes.",
      icon: "game_enduro",
      controls: "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
    },
    %{
      id: "hex_tennis",
      name: "Hex Tennis",
      tagline: "Serve, rally, win",
      description:
        "Top-down tennis duel — automatic hitting, shot angle depends on ball contact position. " <>
          "Full set with tiebreak at 6-6. Deuce, advantage, the works.",
      icon: "game_tennis",
      controls: "Arrow keys or WASD to move, Space or Shift to serve"
    },
    %{
      id: "hex_tennis_quick",
      name: "Hex Tennis: Quick Match",
      tagline: "First to 3 games",
      description:
        "Quick tennis match — first to 3 games wins. " <>
          "Same gameplay, shorter format. No tiebreak needed.",
      icon: "game_tennis",
      controls: "Arrow keys or WASD to move, Space or Shift to serve"
    },
    %{
      id: "hex_tennis_sudden",
      name: "Hex Tennis: Sudden Death",
      tagline: "One point, one game",
      description:
        "Every point wins a game — no 15-30-40, no deuce. " <>
          "First to 6 games takes the set. Pure pressure.",
      icon: "game_tennis",
      controls: "Arrow keys or WASD to move, Space or Shift to serve"
    },
    %{
      id: "hex_skiing",
      name: "Hex Skiing",
      tagline: "Race the avalanche",
      description:
        "Top-down alpine descent through toxic wastelands — dodge mutant trees, " <>
          "clear slalom gates, outrun the avalanche. Best of 3 runs with rising difficulty.",
      icon: "game_skiing",
      controls: "Arrow keys (←/→) or A/D to steer"
    },
    %{
      id: "hex_skiing_escape",
      name: "Hex Skiing: Escape",
      tagline: "Outrun the wasteland",
      description:
        "Infinite descent — the avalanche never stops accelerating. " <>
          "Last skier standing wins. Pure survival.",
      icon: "game_skiing",
      controls: "Arrow keys (←/→) or A/D to steer"
    },
    %{
      id: "hex_skiing_clean",
      name: "Hex Skiing: Clean Run",
      tagline: "Pure downhill duel",
      description:
        "No avalanche, no items — just trees, rocks, and gates. " <>
          "Fastest time down the mountain wins.",
      icon: "game_skiing",
      controls: "Arrow keys (←/→) or A/D to steer"
    },
    %{
      id: "hex_frost",
      name: "Hex Frost",
      tagline: "Build or be frozen",
      description:
        "Arctic construction race — jump on floating ice blocks to build your igloo. " <>
          "Steal your opponent's blocks for a 2-piece swing. Best of 5 rounds with polar bears, crabs, geese, and clams.",
      icon: "game_frost",
      controls: "Arrow keys or WASD to move, Up/Down to jump between rows"
    },
    %{
      id: "hex_frost_blizzard",
      name: "Hex Frost: Blizzard",
      tagline: "One epic round",
      description:
        "1 long round — 20-piece igloo, all enemies from the start, " <>
          "temperature drops slowly. Epic arctic endurance.",
      icon: "game_frost",
      controls: "Arrow keys or WASD to move, Up/Down to jump between rows"
    },
    %{
      id: "hex_frost_peaceful",
      name: "Hex Frost: Peaceful",
      tagline: "No stealing, pure race",
      description:
        "Pure construction race — no block stealing allowed. " <>
          "First to complete the igloo wins. Fair and square.",
      icon: "game_frost",
      controls: "Arrow keys or WASD to move, Up/Down to jump between rows"
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
