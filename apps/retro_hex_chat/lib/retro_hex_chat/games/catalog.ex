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
      tagline: dgettext("games", "Cyberpunk Pong"),
      description:
        dgettext(
          "games",
          "Pong reimagined as cyberpunk arcade — neon glow, CRT scanlines, synth audio. "
        ) <>
          dgettext("games", "First to 11 points (win by 2). Ball speeds up on each rally."),
      icon: "game_pong",
      controls: dgettext("games", "Arrow keys or W/S to move paddle")
    },
    %{
      id: "light_trails",
      name: "Light Trails",
      tagline: dgettext("games", "Don't cross the line"),
      description:
        dgettext("games", "Race across a grid arena leaving a glowing trail behind you. ") <>
          dgettext("games", "Hit a trail or the wall and you're out. Trap your opponent to win."),
      icon: "game_trails",
      controls: dgettext("games", "Arrow keys to change direction")
    },
    %{
      id: "pixel_tanks",
      name: "Pixel Tanks",
      tagline: dgettext("games", "Blast through the maze"),
      description:
        dgettext("games", "Top-down tank combat in a destructible maze. ") <>
          dgettext("games", "Shots ricochet off walls — use geometry to your advantage."),
      icon: "game_tanks",
      controls: dgettext("games", "Arrow keys (Left/Right rotate, Up forward), Space to fire")
    },
    %{
      id: "star_duel",
      name: "Star Duel",
      tagline: dgettext("games", "Dogfight in the void"),
      description:
        dgettext(
          "games",
          "Newtonian space combat — thrust, rotate, and fire missiles in open vacuum. "
        ) <>
          dgettext(
            "games",
            "Wraparound edges, hyperspace warp (20% death chance), first to 7 wins."
          ),
      icon: "game_space",
      controls:
        dgettext("games", "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp")
    },
    %{
      id: "gravity_well",
      name: "Gravity Well",
      tagline: dgettext("games", "Orbit the dying star"),
      description:
        dgettext("games", "Orbital combat around a central gravity star. ") <>
          dgettext(
            "games",
            "Use gravity slingshots, but fly too close and the star kills you. First to 7 wins."
          ),
      icon: "game_gravity",
      controls:
        dgettext("games", "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp")
    },
    %{
      id: "debris_field",
      name: "Debris Field",
      tagline: dgettext("games", "Navigate the wreckage"),
      description:
        dgettext(
          "games",
          "Fight through a field of floating asteroids that block missiles and kill on contact. "
        ) <>
          dgettext(
            "games",
            "Use the debris for cover — or watch it destroy you. First to 7 wins."
          ),
      icon: "game_debris",
      controls:
        dgettext("games", "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp")
    },
    %{
      id: "block_breakers",
      name: "Block Breakers",
      tagline: dgettext("games", "Break blocks together"),
      description:
        dgettext(
          "games",
          "Cooperative Breakout with two paddles — one at the top, one at the bottom. "
        ) <>
          dgettext("games", "Work together to destroy all blocks before running out of lives."),
      icon: "game_breakout",
      controls: dgettext("games", "Arrow keys (Left/Right) to move paddle")
    },
    %{
      id: "hex_warlords",
      name: "Hex Warlords",
      tagline: dgettext("games", "Defend your castle"),
      description:
        dgettext(
          "games",
          "Versus Breakout battle — each player defends a brick castle with a king inside. "
        ) <>
          dgettext(
            "games",
            "Deflect or catch the fireball to smash your opponent's walls. Last king standing wins."
          ),
      icon: "game_warlords",
      controls:
        dgettext("games", "Arrow keys (Up/Down) to move shield, Space to catch/release fireball")
    },
    %{
      id: "hex_raid",
      name: "Hex Raid",
      tagline: dgettext("games", "Two pilots, one river"),
      description:
        dgettext(
          "games",
          "River Raid reimagined for two — race through a scrolling toxic canal, destroy enemies, "
        ) <>
          dgettext(
            "games",
            "steal fuel, and drop mines on your rival. 10 sections of pure chaos."
          ),
      icon: "game_raid",
      controls: dgettext("games", "Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_raid_pacifist",
      name: "Hex Raid: Pacifist",
      tagline: dgettext("games", "No mines, pure skill"),
      description:
        dgettext("games", "River Raid without sabotage — no mines allowed. ") <>
          dgettext("games", "Pure competition for points, fuel, and survival across 10 sections."),
      icon: "game_raid",
      controls: dgettext("games", "Arrow keys to move/speed, Space to fire")
    },
    %{
      id: "hex_raid_blitz",
      name: "Hex Raid: Blitz",
      tagline: dgettext("games", "Fast and furious"),
      description:
        dgettext("games", "5 sections of intense River Raid action — river starts narrow, ") <>
          dgettext("games", "fuel is scarce, mines recharge faster. Quick and chaotic."),
      icon: "game_raid",
      controls: dgettext("games", "Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_boxing",
      name: "Hex Boxing",
      tagline: dgettext("games", "Fists of fury"),
      description:
        dgettext("games", "Top-down boxing — close punches score more. ") <>
          dgettext("games", "Push-and-pull until KO or decision by points. Best of 3 rounds."),
      icon: "game_boxing",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to punch")
    },
    %{
      id: "hex_outlaw",
      name: "Hex Outlaw",
      tagline: dgettext("games", "Draw at high noon"),
      description:
        dgettext("games", "Western duel — two gunslingers and a cactus. ") <>
          dgettext("games", "Dodge bullets you can see coming. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_ricochet",
      name: "Hex Outlaw: Ricochet",
      tagline: dgettext("games", "Bullets bounce back"),
      description:
        dgettext(
          "games",
          "Western duel with bouncing bullets — fire at angles to bypass the wall. "
        ) <>
          dgettext(
            "games",
            "Bullets ricochet once off ceiling/floor. First to 10. Best of 3 rounds."
          ),
      icon: "game_outlaw",
      controls: dgettext("games", "Arrow keys or WASD to move/aim, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_stagecoach",
      name: "Hex Outlaw: Stagecoach",
      tagline: dgettext("games", "Moving cover"),
      description:
        dgettext("games", "Western duel with a stagecoach rolling across the arena. ") <>
          dgettext(
            "games",
            "Time your shots around the moving obstacle. First to 10. Best of 3 rounds."
          ),
      icon: "game_outlaw",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_nml",
      name: "Hex Outlaw: No Man's Land",
      tagline: dgettext("games", "Nowhere to hide"),
      description:
        dgettext("games", "Western duel in open field — no obstacle, full horizontal movement. ") <>
          dgettext("games", "Dodge freely in your half. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_invaders",
      name: "Hex Invaders",
      tagline: dgettext("games", "Your kills are their problem"),
      description:
        dgettext(
          "games",
          "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. "
        ) <>
          dgettext("games", "Combos send extra. 10 waves of escalating chaos."),
      icon: "game_invaders",
      controls: dgettext("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_coop",
      name: "Hex Invaders: Co-op",
      tagline: dgettext("games", "Defend Earth together"),
      description:
        dgettext(
          "games",
          "Classic co-op Space Invaders — two cannons fighting the same alien waves. "
        ) <>
          dgettext("games", "No alien drop. Survive together or fall together."),
      icon: "game_invaders",
      controls: dgettext("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_blitz",
      name: "Hex Invaders: Blitz",
      tagline: dgettext("games", "No mercy, no delay"),
      description:
        dgettext("games", "Blitz Space Invaders — instant alien drops, easier combos, ") <>
          dgettext("games", "5 waves of pure chaos from the start."),
      icon: "game_invaders",
      controls: dgettext("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_enduro",
      name: "Hex Enduro",
      tagline: dgettext("games", "Race through the wasteland"),
      description:
        dgettext("games", "Pseudo-3D racing duel through day, snow, fog, and night. ") <>
          dgettext(
            "games",
            "Overtake AI cars and your opponent, manage fuel, draft in slipstreams. Best of 3 days."
          ),
      icon: "game_enduro",
      controls:
        dgettext("games", "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo")
    },
    %{
      id: "hex_enduro_night",
      name: "Hex Enduro: Night Race",
      tagline: dgettext("games", "Headlights only"),
      description:
        dgettext("games", "3-minute race in permanent darkness with fog bursts. ") <>
          dgettext("games", "Pure reflexes — most overtakes wins. Headlights only visibility."),
      icon: "game_enduro",
      controls:
        dgettext("games", "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo")
    },
    %{
      id: "hex_enduro_sprint",
      name: "Hex Enduro: Sprint",
      tagline: dgettext("games", "90 seconds of fury"),
      description:
        dgettext("games", "Daylight sprint — no weather changes, no fuel drain, just speed. ") <>
          dgettext("games", "90 seconds to score maximum overtakes."),
      icon: "game_enduro",
      controls:
        dgettext("games", "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo")
    },
    %{
      id: "hex_tennis",
      name: "Hex Tennis",
      tagline: dgettext("games", "Serve, rally, win"),
      description:
        dgettext(
          "games",
          "Top-down tennis duel — automatic hitting, shot angle depends on ball contact position. "
        ) <>
          dgettext("games", "Full set with tiebreak at 6-6. Deuce, advantage, the works."),
      icon: "game_tennis",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_quick",
      name: "Hex Tennis: Quick Match",
      tagline: dgettext("games", "First to 3 games"),
      description:
        dgettext("games", "Quick tennis match — first to 3 games wins. ") <>
          dgettext("games", "Same gameplay, shorter format. No tiebreak needed."),
      icon: "game_tennis",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_sudden",
      name: "Hex Tennis: Sudden Death",
      tagline: dgettext("games", "One point, one game"),
      description:
        dgettext("games", "Every point wins a game — no 15-30-40, no deuce. ") <>
          dgettext("games", "First to 6 games takes the set. Pure pressure."),
      icon: "game_tennis",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_skiing",
      name: "Hex Skiing",
      tagline: dgettext("games", "Race the avalanche"),
      description:
        dgettext(
          "games",
          "Top-down alpine descent through toxic wastelands — dodge mutant trees, "
        ) <>
          dgettext(
            "games",
            "clear slalom gates, outrun the avalanche. Best of 3 runs with rising difficulty."
          ),
      icon: "game_skiing",
      controls: dgettext("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_escape",
      name: "Hex Skiing: Escape",
      tagline: dgettext("games", "Outrun the wasteland"),
      description:
        dgettext("games", "Infinite descent — the avalanche never stops accelerating. ") <>
          dgettext("games", "Last skier standing wins. Pure survival."),
      icon: "game_skiing",
      controls: dgettext("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_clean",
      name: "Hex Skiing: Clean Run",
      tagline: dgettext("games", "Pure downhill duel"),
      description:
        dgettext("games", "No avalanche, no items — just trees, rocks, and gates. ") <>
          dgettext("games", "Fastest time down the mountain wins."),
      icon: "game_skiing",
      controls: dgettext("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_frost",
      name: "Hex Frost",
      tagline: dgettext("games", "Build or be frozen"),
      description:
        dgettext(
          "games",
          "Arctic construction race — jump on floating ice blocks to build your igloo. "
        ) <>
          dgettext(
            "games",
            "Steal your opponent's blocks for a 2-piece swing. Best of 5 rounds with polar bears, crabs, geese, and clams."
          ),
      icon: "game_frost",
      controls: dgettext("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_blizzard",
      name: "Hex Frost: Blizzard",
      tagline: dgettext("games", "One epic round"),
      description:
        dgettext("games", "1 long round — 20-piece igloo, all enemies from the start, ") <>
          dgettext("games", "temperature drops slowly. Epic arctic endurance."),
      icon: "game_frost",
      controls: dgettext("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_peaceful",
      name: "Hex Frost: Peaceful",
      tagline: dgettext("games", "No stealing, pure race"),
      description:
        dgettext("games", "Pure construction race — no block stealing allowed. ") <>
          dgettext("games", "First to complete the igloo wins. Fair and square."),
      icon: "game_frost",
      controls: dgettext("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_hockey",
      name: "Hex Hockey",
      tagline: dgettext("games", "Neon ice warfare"),
      description:
        dgettext(
          "games",
          "Top-down ice hockey in a cyberpunk arena — control your field player, "
        ) <>
          dgettext(
            "games",
            "shoot, tackle, and score while your AI goalie defends. 3 periods of 2 minutes."
          ),
      icon: "game_hockey",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_blitz",
      name: "Hex Hockey: Blitz",
      tagline: dgettext("games", "Fast and brutal"),
      description:
        dgettext("games", "One period of 3 minutes — faster puck, higher tackle success rate. ") <>
          dgettext("games", "Pure intensity from start to finish."),
      icon: "game_hockey",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_showdown",
      name: "Hex Hockey: Showdown",
      tagline: dgettext("games", "First to five"),
      description:
        dgettext(
          "games",
          "No timer — first to 5 goals wins. Puck speed increases with each goal scored. "
        ) <>
          dgettext("games", "The pressure builds every time the net shakes."),
      icon: "game_hockey",
      controls: dgettext("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
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
