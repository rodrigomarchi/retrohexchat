defmodule RetroHexChat.VirtualSpace.Map do
  @moduledoc """
  Registry and helpers for virtual space map definitions.

  Maps are authored in Elixir (`RetroHexChat.VirtualSpace.Maps.*`) and are the
  canonical source of collision, zones, seats and interactables. Clients get
  the full definition in the `space_init` payload and never keep their own
  copy. This registry is the only place that resolves a `map_id`, so
  arbitrary ids from clients never reach map code.
  """

  alias RetroHexChat.VirtualSpace.Maps.Construct
  alias RetroHexChat.VirtualSpace.Maps.EndOfTime
  alias RetroHexChat.VirtualSpace.Maps.GameRoom
  alias RetroHexChat.VirtualSpace.Maps.Office

  @maps %{
    "construct" => Construct,
    "end_of_time" => EndOfTime,
    "game_room" => GameRoom,
    "office" => Office
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

  # ── Decoding the authored JSON ──
  #
  # Every map is authored as JSON and decoded into the same shapes; these are
  # the pieces whose shape does not depend on the map.

  @doc "Where people appear: `%{x, y, dir}` per spawn point."
  @spec decode_spawn([map()]) :: [map()]
  def decode_spawn(points), do: Enum.map(points, &%{x: &1["x"], y: &1["y"], dir: &1["dir"]})

  @doc "Blocked rectangles: `%{x, y, w, h, kind}`."
  @spec decode_collision([map()]) :: [map()]
  def decode_collision(rects),
    do: Enum.map(rects, &%{x: &1["x"], y: &1["y"], w: &1["w"], h: &1["h"], kind: &1["kind"]})

  @doc "Named areas: `%{id, kind, x, y, w, h}`."
  @spec decode_zones([map()]) :: [map()]
  def decode_zones(zones) do
    Enum.map(
      zones,
      &%{id: &1["id"], kind: &1["kind"], x: &1["x"], y: &1["y"], w: &1["w"], h: &1["h"]}
    )
  end

  @doc """
  Things a participant can use (E). A `confirm` modal asks before acting, and
  its `action` names what Yes does.
  """
  @spec decode_interactables([map()] | nil) :: [map()]
  def decode_interactables(items) do
    Enum.map(items || [], fn i ->
      %{
        id: i["id"],
        kind: i["kind"],
        x: i["x"],
        y: i["y"],
        title: i["title"],
        modal: %{kind: i["modal"]["kind"], action: i["modal"]["action"]}
      }
    end)
  end
end
