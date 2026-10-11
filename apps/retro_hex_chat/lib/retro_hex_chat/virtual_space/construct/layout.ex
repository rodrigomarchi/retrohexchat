defmodule RetroHexChat.VirtualSpace.Construct.Layout do
  @moduledoc """
  What people have placed in a Construct, and the rules for placing it.

  Pure: the runtime holds the items, this module answers whether an edit may
  happen and what the map looks like with the items on it. An item is one tile
  of floor, whatever its art overhangs — a tree's canopy rises into the void,
  its trunk is what you bump into.

  The base map (`Maps.Construct`) carries the catalog of placeable kinds, the
  tiles nobody may build on (the gate, the ground in front of it, the spawns)
  and how many items a room holds. Every edit is checked here, on the server:
  the client's green or red ghost is a preview of this answer, never a
  substitute for it.
  """

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap

  @dirs ~w(down right)

  @type item :: %{
          id: String.t(),
          kind: String.t(),
          x: integer(),
          y: integer(),
          dir: String.t(),
          placed_by: String.t() | nil
        }

  @type op ::
          {:place, String.t(), integer(), integer(), String.t()}
          | {:move, String.t(), integer(), integer()}
          | {:remove, String.t()}
          | {:rotate, String.t()}

  @type error ::
          :unknown_kind
          | :unknown_item
          | :out_of_bounds
          | :reserved
          | :occupied
          | :someone_there
          | :seat_taken
          | :would_trap
          | :full

  @typedoc """
  What an edit is judged against, beyond the items themselves: the tiles people
  stand on (nobody gets a table dropped on their feet, nobody gets walled in)
  and the chairs somebody is sitting in.
  """
  @type context :: %{
          avatars: [{integer(), integer()}],
          seated: MapSet.t(String.t())
        }

  @doc "The facings an item can be placed in."
  @spec dirs() :: [String.t()]
  def dirs, do: @dirs

  @doc """
  The map with the items on it: each item adds a standing prop, a blocked tile,
  and whatever its kind brings — a seat for a chair, a light for a lamp.
  """
  @spec apply(map(), [item()]) :: map()
  def apply(base, items) do
    catalog = Map.get(base, :catalog, %{})
    placed = Enum.filter(items, &Map.has_key?(catalog, &1.kind))

    base
    |> update_in([:layers, :decor], &(&1 ++ Enum.map(placed, fn i -> decor(catalog, i) end)))
    |> Map.update!(:collision, &(&1 ++ Enum.map(placed, fn i -> blocked(i) end)))
    |> Map.update(:seats, seats(catalog, placed), &(&1 ++ seats(catalog, placed)))
    |> Map.update(:lights, lights(catalog, placed), &(&1 ++ lights(catalog, placed)))
    |> Map.put(:items, Enum.map(placed, &view/1))
  end

  @doc """
  The part of the map an edit changes, for the clients already standing in it.
  The base never changes, so this is all a client needs to redraw the room.
  """
  @spec patch(map(), non_neg_integer()) :: map()
  def patch(map, revision) do
    %{
      revision: revision,
      items: map.items,
      decor: map.layers.decor,
      collision: map.collision,
      seats: map.seats,
      lights: map.lights
    }
  end

  @doc """
  Apply one edit to the items, or say why it cannot happen.

  `actor` is the nickname that made the edit, recorded on a placed item.
  """
  @spec edit(map(), [item()], op(), context(), String.t()) ::
          {:ok, [item()]} | {:error, error()}
  def edit(base, items, {:place, kind, x, y, dir}, context, actor) do
    cond do
      not Map.has_key?(Map.get(base, :catalog, %{}), kind) ->
        {:error, :unknown_kind}

      length(items) >= Map.get(base, :max_items, 0) ->
        {:error, :full}

      true ->
        item = %{
          id: Ecto.UUID.generate(),
          kind: kind,
          x: x,
          y: y,
          dir: dir_or_default(dir),
          placed_by: actor
        }

        with :ok <- tile_free(base, items, context, x, y, nil) do
          checked(base, items ++ [item], context)
        end
    end
  end

  def edit(base, items, {:move, id, x, y}, context, _actor) do
    with {:ok, item} <- find(items, id),
         :ok <- not_sat_on(item, context),
         :ok <- tile_free(base, items, context, x, y, id) do
      checked(base, replace(items, %{item | x: x, y: y}), context)
    end
  end

  def edit(_base, items, {:remove, id}, context, _actor) do
    with {:ok, item} <- find(items, id),
         :ok <- not_sat_on(item, context) do
      {:ok, Enum.reject(items, &(&1.id == id))}
    end
  end

  def edit(_base, items, {:rotate, id}, context, _actor) do
    with {:ok, item} <- find(items, id),
         :ok <- not_sat_on(item, context) do
      {:ok, replace(items, %{item | dir: next_dir(item.dir)})}
    end
  end

  @doc """
  Items read back from storage, keeping only the ones this build can draw and
  that still land on buildable floor. A stored row is data from an older build,
  and a kind that has since been retired must not break the room.
  """
  @spec normalize(map(), [map()]) :: [item()]
  def normalize(base, raw_items) when is_list(raw_items) do
    catalog = Map.get(base, :catalog, %{})

    raw_items
    |> Enum.flat_map(&normalize_item/1)
    |> Enum.filter(&Map.has_key?(catalog, &1.kind))
    |> Enum.uniq_by(&{&1.x, &1.y})
    |> Enum.filter(&buildable?(base, &1.x, &1.y))
    |> Enum.take(Map.get(base, :max_items, 0))
  end

  def normalize(_base, _raw_items), do: []

  @doc "An item in the shape storage and the wire carry it."
  @spec view(item()) :: map()
  def view(item) do
    %{
      id: item.id,
      kind: item.kind,
      x: item.x,
      y: item.y,
      dir: item.dir,
      placed_by: item.placed_by
    }
  end

  # --- Private ---

  defp normalize_item(%{} = raw) do
    get = fn key -> Map.get(raw, key) || Map.get(raw, Atom.to_string(key)) end

    with id when is_binary(id) <- get.(:id),
         kind when is_binary(kind) <- get.(:kind),
         x when is_integer(x) <- get.(:x),
         y when is_integer(y) <- get.(:y) do
      [
        %{
          id: id,
          kind: kind,
          x: x,
          y: y,
          dir: dir_or_default(get.(:dir)),
          placed_by: get.(:placed_by)
        }
      ]
    else
      _malformed -> []
    end
  end

  defp normalize_item(_raw), do: []

  defp decor(catalog, item) do
    %{
      x: item.x,
      y: item.y,
      tile: get_in(catalog, [item.kind, :tiles, item.dir]),
      sort: "stand",
      item_id: item.id
    }
  end

  defp blocked(item), do: %{x: item.x, y: item.y, w: 1, h: 1, kind: "item"}

  defp seats(catalog, items) do
    for item <- items, get_in(catalog, [item.kind, :seat]) do
      %{id: seat_id(item), x: item.x, y: item.y, dir: item.dir, item_id: item.id}
    end
  end

  defp lights(catalog, items) do
    for item <- items, light <- get_in(catalog, [item.kind, :lights]) || [] do
      Map.merge(light, %{x: item.x, y: item.y})
    end
  end

  @doc "The seat a placed chair offers."
  @spec seat_id(item()) :: String.t()
  def seat_id(item), do: "seat:" <> item.id

  defp find(items, id) do
    case Enum.find(items, &(&1.id == id)) do
      nil -> {:error, :unknown_item}
      item -> {:ok, item}
    end
  end

  defp replace(items, updated) do
    Enum.map(items, fn item -> if item.id == updated.id, do: updated, else: item end)
  end

  defp not_sat_on(item, %{seated: seated}) do
    if MapSet.member?(seated, seat_id(item)), do: {:error, :seat_taken}, else: :ok
  end

  defp tile_free(base, items, context, x, y, moving_id) do
    cond do
      not in_bounds?(base, x, y) -> {:error, :out_of_bounds}
      not buildable?(base, x, y) -> {:error, :reserved}
      Enum.any?(items, &(&1.id != moving_id and &1.x == x and &1.y == y)) -> {:error, :occupied}
      {x, y} in context.avatars -> {:error, :someone_there}
      true -> :ok
    end
  end

  # An edit that closes the last way between somebody and the gate is refused:
  # the room is shared, and one person's wall is everyone else's prison.
  defp checked(base, items, context) do
    if everyone_reaches_gate?(base, items, context.avatars),
      do: {:ok, items},
      else: {:error, :would_trap}
  end

  defp everyone_reaches_gate?(_base, _items, []), do: true

  defp everyone_reaches_gate?(base, items, avatars) do
    blocked =
      base
      |> SpaceMap.collision_set()
      |> MapSet.union(MapSet.new(items, &{&1.x, &1.y}))

    gate = gate_apron(base, blocked)
    reachable = flood(base, blocked, Enum.to_list(gate), gate)
    Enum.all?(avatars, &(neighbours_or_self(&1) |> Enum.any?(fn t -> t in reachable end)))
  end

  # The walkable reserved tiles: the ground in front of the gate and the spawns.
  defp gate_apron(base, blocked) do
    base
    |> reserved()
    |> Enum.reject(&MapSet.member?(blocked, &1))
    |> MapSet.new()
  end

  defp flood(_base, _blocked, [], seen), do: seen

  defp flood(base, blocked, [{x, y} | rest], seen) do
    next =
      for {nx, ny} <- [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}],
          in_bounds?(base, nx, ny),
          not MapSet.member?(blocked, {nx, ny}),
          not MapSet.member?(seen, {nx, ny}),
          do: {nx, ny}

    flood(base, blocked, next ++ rest, MapSet.union(seen, MapSet.new(next)))
  end

  # Somebody sitting is on a chair's own blocked tile; they are free if they can
  # step off it, which is what reaching any neighbour means.
  defp neighbours_or_self({x, y}), do: [{x, y}, {x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  defp buildable?(base, x, y) do
    in_bounds?(base, x, y) and
      not MapSet.member?(reserved(base), {x, y}) and
      not MapSet.member?(SpaceMap.collision_set(base), {x, y})
  end

  defp reserved(base), do: MapSet.new(Map.get(base, :reserved, []), &{&1.x, &1.y})

  defp in_bounds?(base, x, y), do: x >= 0 and y >= 0 and x < base.width and y < base.height

  defp dir_or_default(dir) when dir in @dirs, do: dir
  defp dir_or_default(_dir), do: hd(@dirs)

  defp next_dir(dir) do
    index = Enum.find_index(@dirs, &(&1 == dir)) || 0
    Enum.at(@dirs, rem(index + 1, length(@dirs)))
  end
end
