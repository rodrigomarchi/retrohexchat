defmodule RetroHexChat.Games.Catalog do
  @moduledoc """
  Registry of available P2P games.
  Each game has an id, name, description, and icon identifier.
  All games are real-time action for two players.
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
      tagline: "Pong with a twist",
      description:
        "Classic Pong reimagined with hexagonal paddles and power-ups. " <>
          "The ball accelerates progressively — how long can you keep up?",
      icon: "game_pong",
      controls: "Arrow keys (Up/Down) to move paddle"
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
      controls: "Arrow keys to move, Space to fire"
    },
    %{
      id: "star_duel",
      name: "Star Duel",
      tagline: "Dogfight among the stars",
      description:
        "Space dogfight with inertial physics and asteroid obstacles. " <>
          "Thrust, rotate, and fire — but watch your momentum.",
      icon: "game_space",
      controls: "Arrow keys to thrust/rotate, Space to fire"
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
