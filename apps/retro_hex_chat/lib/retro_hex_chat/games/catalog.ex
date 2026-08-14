defmodule RetroHexChat.Games.Catalog do
  @moduledoc """
  Registry of available real-time browser games.
  Each game has an id, name, description, and icon identifier.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @solo_game_ids [
    "hex_pong",
    "light_trails",
    "star_duel",
    "gravity_well",
    "debris_field",
    "hex_outlaw",
    "hex_outlaw_ricochet",
    "hex_outlaw_stagecoach",
    "hex_outlaw_nml"
  ]

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
      tagline: dgettext_noop("games", "Cyberpunk Pong"),
      description:
        dgettext(
          "games",
          "Pong reimagined as cyberpunk arcade — neon glow, CRT scanlines, synth audio. "
        ) <>
          dgettext_noop("games", "First to 11 points (win by 2). Ball speeds up on each rally."),
      icon: "game_pong",
      controls: dgettext_noop("games", "Arrow keys or W/S to move paddle")
    },
    %{
      id: "light_trails",
      name: "Light Trails",
      tagline: dgettext_noop("games", "Don't cross the line"),
      description:
        dgettext_noop("games", "Race across a grid arena leaving a glowing trail behind you. ") <>
          dgettext_noop(
            "games",
            "Hit a trail or the wall and you're out. Trap your opponent to win."
          ),
      icon: "game_trails",
      controls: dgettext_noop("games", "Arrow keys to change direction")
    },
    %{
      id: "pixel_tanks",
      name: "Pixel Tanks",
      tagline: dgettext_noop("games", "Blast through the maze"),
      description:
        dgettext_noop("games", "Top-down tank combat in a destructible maze. ") <>
          dgettext_noop("games", "Shots ricochet off walls — use geometry to your advantage."),
      icon: "game_tanks",
      controls:
        dgettext_noop("games", "Arrow keys (Left/Right rotate, Up forward), Space to fire")
    },
    %{
      id: "star_duel",
      name: "Star Duel",
      tagline: dgettext_noop("games", "Dogfight in the void"),
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
        dgettext_noop(
          "games",
          "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
        )
    },
    %{
      id: "gravity_well",
      name: "Gravity Well",
      tagline: dgettext_noop("games", "Orbit the dying star"),
      description:
        dgettext_noop("games", "Orbital combat around a central gravity star. ") <>
          dgettext(
            "games",
            "Use gravity slingshots, but fly too close and the star kills you. First to 7 wins."
          ),
      icon: "game_gravity",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
        )
    },
    %{
      id: "debris_field",
      name: "Debris Field",
      tagline: dgettext_noop("games", "Navigate the wreckage"),
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
        dgettext_noop(
          "games",
          "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
        )
    },
    %{
      id: "block_breakers",
      name: "Block Breakers",
      tagline: dgettext_noop("games", "Break blocks together"),
      description:
        dgettext(
          "games",
          "Cooperative Breakout with two paddles — one at the top, one at the bottom. "
        ) <>
          dgettext_noop(
            "games",
            "Work together to destroy all blocks before running out of lives."
          ),
      icon: "game_breakout",
      controls: dgettext_noop("games", "Arrow keys (Left/Right) to move paddle")
    },
    %{
      id: "hex_warlords",
      name: "Hex Warlords",
      tagline: dgettext_noop("games", "Defend your castle"),
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
        dgettext_noop(
          "games",
          "Arrow keys (Up/Down) to move shield, Space to catch/release fireball"
        )
    },
    %{
      id: "hex_raid",
      name: "Hex Raid",
      tagline: dgettext_noop("games", "Two pilots, one river"),
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
      controls:
        dgettext_noop("games", "Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_raid_pacifist",
      name: "Hex Raid: Pacifist",
      tagline: dgettext_noop("games", "No mines, pure skill"),
      description:
        dgettext_noop("games", "River Raid without sabotage — no mines allowed. ") <>
          dgettext_noop(
            "games",
            "Pure competition for points, fuel, and survival across 10 sections."
          ),
      icon: "game_raid",
      controls: dgettext_noop("games", "Arrow keys to move/speed, Space to fire")
    },
    %{
      id: "hex_raid_blitz",
      name: "Hex Raid: Blitz",
      tagline: dgettext_noop("games", "Fast and furious"),
      description:
        dgettext_noop("games", "5 sections of intense River Raid action — river starts narrow, ") <>
          dgettext_noop("games", "fuel is scarce, mines recharge faster. Quick and chaotic."),
      icon: "game_raid",
      controls:
        dgettext_noop("games", "Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_boxing",
      name: "Hex Boxing",
      tagline: dgettext_noop("games", "Fists of fury"),
      description:
        dgettext_noop("games", "Top-down boxing — close punches score more. ") <>
          dgettext_noop(
            "games",
            "Push-and-pull until KO or decision by points. Best of 3 rounds."
          ),
      icon: "game_boxing",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to punch")
    },
    %{
      id: "hex_outlaw",
      name: "Hex Outlaw",
      tagline: dgettext_noop("games", "Draw at high noon"),
      description:
        dgettext_noop("games", "Western duel — two gunslingers and a cactus. ") <>
          dgettext_noop(
            "games",
            "Dodge bullets you can see coming. First to 10. Best of 3 rounds."
          ),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_ricochet",
      name: "Hex Outlaw: Ricochet",
      tagline: dgettext_noop("games", "Bullets bounce back"),
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
      controls: dgettext_noop("games", "Arrow keys or WASD to move/aim, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_stagecoach",
      name: "Hex Outlaw: Stagecoach",
      tagline: dgettext_noop("games", "Moving cover"),
      description:
        dgettext_noop("games", "Western duel with a stagecoach rolling across the arena. ") <>
          dgettext(
            "games",
            "Time your shots around the moving obstacle. First to 10. Best of 3 rounds."
          ),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_nml",
      name: "Hex Outlaw: No Man's Land",
      tagline: dgettext_noop("games", "Nowhere to hide"),
      description:
        dgettext_noop(
          "games",
          "Western duel in open field — no obstacle, full horizontal movement. "
        ) <>
          dgettext_noop("games", "Dodge freely in your half. First to 10. Best of 3 rounds."),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_invaders",
      name: "Hex Invaders",
      tagline: dgettext_noop("games", "Your kills are their problem"),
      description:
        dgettext(
          "games",
          "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. "
        ) <>
          dgettext_noop("games", "Combos send extra. 10 waves of escalating chaos."),
      icon: "game_invaders",
      controls: dgettext_noop("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_coop",
      name: "Hex Invaders: Co-op",
      tagline: dgettext_noop("games", "Defend Earth together"),
      description:
        dgettext(
          "games",
          "Classic co-op Space Invaders — two cannons fighting the same alien waves. "
        ) <>
          dgettext_noop("games", "No alien drop. Survive together or fall together."),
      icon: "game_invaders",
      controls: dgettext_noop("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_blitz",
      name: "Hex Invaders: Blitz",
      tagline: dgettext_noop("games", "No mercy, no delay"),
      description:
        dgettext_noop("games", "Blitz Space Invaders — instant alien drops, easier combos, ") <>
          dgettext_noop("games", "5 waves of pure chaos from the start."),
      icon: "game_invaders",
      controls: dgettext_noop("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_enduro",
      name: "Hex Enduro",
      tagline: dgettext_noop("games", "Race through the wasteland"),
      description:
        dgettext_noop("games", "Pseudo-3D racing duel through day, snow, fog, and night. ") <>
          dgettext(
            "games",
            "Overtake AI cars and your opponent, manage fuel, draft in slipstreams. Best of 3 days."
          ),
      icon: "game_enduro",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
        )
    },
    %{
      id: "hex_enduro_night",
      name: "Hex Enduro: Night Race",
      tagline: dgettext_noop("games", "Headlights only"),
      description:
        dgettext_noop("games", "3-minute race in permanent darkness with fog bursts. ") <>
          dgettext_noop(
            "games",
            "Pure reflexes — most overtakes wins. Headlights only visibility."
          ),
      icon: "game_enduro",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
        )
    },
    %{
      id: "hex_enduro_sprint",
      name: "Hex Enduro: Sprint",
      tagline: dgettext_noop("games", "90 seconds of fury"),
      description:
        dgettext_noop(
          "games",
          "Daylight sprint — no weather changes, no fuel drain, just speed. "
        ) <>
          dgettext_noop("games", "90 seconds to score maximum overtakes."),
      icon: "game_enduro",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
        )
    },
    %{
      id: "hex_tennis",
      name: "Hex Tennis",
      tagline: dgettext_noop("games", "Serve, rally, win"),
      description:
        dgettext(
          "games",
          "Top-down tennis duel — automatic hitting, shot angle depends on ball contact position. "
        ) <>
          dgettext_noop("games", "Full set with tiebreak at 6-6. Deuce, advantage, the works."),
      icon: "game_tennis",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_quick",
      name: "Hex Tennis: Quick Match",
      tagline: dgettext_noop("games", "First to 3 games"),
      description:
        dgettext_noop("games", "Quick tennis match — first to 3 games wins. ") <>
          dgettext_noop("games", "Same gameplay, shorter format. No tiebreak needed."),
      icon: "game_tennis",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_sudden",
      name: "Hex Tennis: Sudden Death",
      tagline: dgettext_noop("games", "One point, one game"),
      description:
        dgettext_noop("games", "Every point wins a game — no 15-30-40, no deuce. ") <>
          dgettext_noop("games", "First to 6 games takes the set. Pure pressure."),
      icon: "game_tennis",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_skiing",
      name: "Hex Skiing",
      tagline: dgettext_noop("games", "Race the avalanche"),
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
      controls: dgettext_noop("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_escape",
      name: "Hex Skiing: Escape",
      tagline: dgettext_noop("games", "Outrun the wasteland"),
      description:
        dgettext_noop("games", "Infinite descent — the avalanche never stops accelerating. ") <>
          dgettext_noop("games", "Last skier standing wins. Pure survival."),
      icon: "game_skiing",
      controls: dgettext_noop("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_clean",
      name: "Hex Skiing: Clean Run",
      tagline: dgettext_noop("games", "Pure downhill duel"),
      description:
        dgettext_noop("games", "No avalanche, no items — just trees, rocks, and gates. ") <>
          dgettext_noop("games", "Fastest time down the mountain wins."),
      icon: "game_skiing",
      controls: dgettext_noop("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_frost",
      name: "Hex Frost",
      tagline: dgettext_noop("games", "Build or be frozen"),
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
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_blizzard",
      name: "Hex Frost: Blizzard",
      tagline: dgettext_noop("games", "One epic round"),
      description:
        dgettext_noop("games", "1 long round — 20-piece igloo, all enemies from the start, ") <>
          dgettext_noop("games", "temperature drops slowly. Epic arctic endurance."),
      icon: "game_frost",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_peaceful",
      name: "Hex Frost: Peaceful",
      tagline: dgettext_noop("games", "No stealing, pure race"),
      description:
        dgettext_noop("games", "Pure construction race — no block stealing allowed. ") <>
          dgettext_noop("games", "First to complete the igloo wins. Fair and square."),
      icon: "game_frost",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_hockey",
      name: "Hex Hockey",
      tagline: dgettext_noop("games", "Neon ice warfare"),
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
      controls:
        dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_blitz",
      name: "Hex Hockey: Blitz",
      tagline: dgettext_noop("games", "Fast and brutal"),
      description:
        dgettext_noop(
          "games",
          "One period of 3 minutes — faster puck, higher tackle success rate. "
        ) <>
          dgettext_noop("games", "Pure intensity from start to finish."),
      icon: "game_hockey",
      controls:
        dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_showdown",
      name: "Hex Hockey: Showdown",
      tagline: dgettext_noop("games", "First to five"),
      description:
        dgettext(
          "games",
          "No timer — first to 5 goals wins. Puck speed increases with each goal scored. "
        ) <>
          dgettext_noop("games", "The pressure builds every time the net shakes."),
      icon: "game_hockey",
      controls:
        dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    }
  ]

  @spec list_games() :: [game()]
  def list_games, do: Enum.map(@games, &translate_game/1)

  @spec list_solo_games() :: [game()]
  def list_solo_games do
    @games
    |> Enum.filter(&solo_game_id?(&1.id))
    |> Enum.map(&translate_game/1)
  end

  @spec get_game(String.t()) :: {:ok, game()} | {:error, :not_found}
  def get_game(id) do
    case Enum.find(@games, &(&1.id == id)) do
      nil -> {:error, :not_found}
      game -> {:ok, translate_game(game)}
    end
  end

  @spec valid_game_id?(String.t()) :: boolean()
  def valid_game_id?(id), do: Enum.any?(@games, &(&1.id == id))

  @spec solo_game_id?(String.t()) :: boolean()
  def solo_game_id?(id), do: id in @solo_game_ids

  @spec game_ids() :: [String.t()]
  def game_ids, do: Enum.map(@games, & &1.id)

  defp translate_game(game) do
    game
    |> Map.update!(:tagline, &t/1)
    |> Map.update!(:controls, &t/1)
  end

  defp t(msgid), do: Gettext.dgettext(RetroHexChat.Gettext, "games", msgid)
end
