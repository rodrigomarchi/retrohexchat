defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest map: a tile-for-tile transcription of the reference overworld.
  Each cell of the reference screenshot was matched against the sliced tileset
  (template matching) to pick the closest tile, so the layout — cliffs, clearing,
  cabin, pond, stumps, logs and dark-grass patches — sits exactly where the
  reference has it. The `priv/maps/elfic_forest.json` data file holds the tile
  legend, the row-major floor of tile indices and the set of blocked tile types;
  this module expands them into the map definition, deriving collision from the
  blocked tiles and a spawn from a walkable cell near the centre.
  """

  @spec definition() :: map()
  def definition do
    data = load()
    legend = data["legend"]
    width = data["width"]
    height = data["height"]
    floor_idx = data["floor"]
    blocked = MapSet.new(data["blocked"])
    trees = Elixir.Map.get(data, "decor", [])

    tree_cells =
      for [x, y] <- trees, dx <- 0..1, dy <- 0..1, into: MapSet.new(), do: {x + dx, y + dy}

    floor = Enum.map(floor_idx, fn row -> Enum.map(row, &Elixir.Enum.at(legend, &1)) end)
    spawn = spawn_cells(floor_idx, blocked, tree_cells, width, height)

    %{
      id: "elfic_forest",
      version: 1,
      width: width,
      height: height,
      tile_size: 16,
      ground: Elixir.Enum.at(legend, ground_index(floor_idx)),
      spawn: spawn,
      layers: %{floor: floor, decor: canopies(trees), above: []},
      collision: collision(floor_idx, blocked) ++ tree_collision(tree_cells),
      zones: zones(spawn, width, height),
      interactables: [],
      seats: []
    }
  end

  defp canopies(trees), do: Enum.map(trees, fn [x, y] -> %{x: x, y: y, tile: "tree"} end)

  defp tree_collision(tree_cells) do
    Enum.map(tree_cells, fn {x, y} -> %{x: x, y: y, w: 1, h: 1, kind: "tree"} end)
  end

  # ── Data ──────────────────────────────────────────────────────────

  defp load do
    :retro_hex_chat
    |> :code.priv_dir()
    |> Path.join("maps/elfic_forest.json")
    |> File.read!()
    |> JSON.decode!()
  end

  # The most frequent tile is the grass base drawn under transparent cells.
  defp ground_index(floor_idx) do
    floor_idx
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.max_by(fn {_idx, count} -> count end)
    |> elem(0)
  end

  # ── Collision & spawn ─────────────────────────────────────────────

  defp collision(floor_idx, blocked) do
    for {row, y} <- Enum.with_index(floor_idx),
        {tile_idx, x} <- Enum.with_index(row),
        MapSet.member?(blocked, tile_idx) do
      %{x: x, y: y, w: 1, h: 1, kind: "forest"}
    end
  end

  # Six spawn cells: the first walkable tiles found spiralling out from centre.
  defp spawn_cells(floor_idx, blocked, tree_cells, width, height) do
    cx = div(width, 2)
    cy = div(height, 2)

    for r <- 0..max(width, height),
        {x, y} <- ring(cx, cy, r),
        x >= 0 and y >= 0 and x < width and y < height,
        walkable?(floor_idx, blocked, x, y) and not MapSet.member?(tree_cells, {x, y}),
        reduce: [] do
      acc when length(acc) >= 6 -> acc
      acc -> acc ++ [%{x: x, y: y, dir: "down"}]
    end
  end

  defp ring(cx, cy, 0), do: [{cx, cy}]

  defp ring(cx, cy, r) do
    for dx <- -r..r, dy <- -r..r, abs(dx) == r or abs(dy) == r, do: {cx + dx, cy + dy}
  end

  defp walkable?(floor_idx, blocked, x, y) do
    tile_idx = floor_idx |> Elixir.Enum.at(y) |> Elixir.Enum.at(x)
    not MapSet.member?(blocked, tile_idx)
  end

  # ── Zones ─────────────────────────────────────────────────────────

  defp zones([%{x: sx, y: sy} | _], width, height) do
    [
      %{
        id: "spawn",
        kind: "spawn",
        x: clamp(sx - 3, width),
        y: clamp(sy - 3, height),
        w: 6,
        h: 6
      },
      %{id: "forest", kind: "common", x: 1, y: 1, w: width - 2, h: height - 2}
    ]
  end

  defp clamp(v, _limit) when v < 0, do: 0
  defp clamp(v, _limit), do: v
end
