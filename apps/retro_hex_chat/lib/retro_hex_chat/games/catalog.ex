defmodule RetroHexChat.Games.Catalog do
  @moduledoc """
  Registry of available P2P games.
  Each game has an id, name, description, and icon identifier.
  All games are real-time action for two players (12 games total).
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
