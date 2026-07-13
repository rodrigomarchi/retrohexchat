defmodule RetroHexChat.VirtualSpace.Map do
  @moduledoc """
  Registry and helpers for virtual space map definitions.

  Maps are authored in Elixir (`RetroHexChat.VirtualSpace.Maps.*`) and are the
  canonical source of collision, zones, seats and interactables. Clients get
  the full definition in the `space_init` payload and never keep their own
  copy. This registry is the only place that resolves a `map_id`, so
  arbitrary ids from clients never reach map code.
  """

  alias RetroHexChat.VirtualSpace.Maps.EndOfTime

  @maps %{
    "end_of_time" => EndOfTime
  }

  @spec get(String.t()) :: {:ok, map()} | {:error, :unknown_map}
  def get(map_id) do
    case Elixir.Map.fetch(@maps, map_id) do
      {:ok, module} -> {:ok, module.definition()}
      :error -> {:error, :unknown_map}
    end
  end

  @spec ids() :: [String.t()]
  def ids, do: Elixir.Map.keys(@maps)

  @doc """
  Expands the collision rects of a definition into a `MapSet` of blocked
  `{x, y}` tiles, the shape used for authoritative movement validation.
  """
  @spec collision_set(map()) :: MapSet.t({integer(), integer()})
  def collision_set(%{collision: rects}) do
    for %{x: x, y: y, w: w, h: h} <- rects,
        tile_x <- x..(x + w - 1),
        tile_y <- y..(y + h - 1),
        into: MapSet.new() do
      {tile_x, tile_y}
    end
  end
end
