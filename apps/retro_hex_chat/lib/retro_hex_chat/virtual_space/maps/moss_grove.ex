defmodule RetroHexChat.VirtualSpace.Maps.MossGrove do
  @moduledoc """
  Moss Grove: a compact tree-ringed clearing with a cave mouth and scattered
  boulders, authored over the shared `overworld.png` vocabulary. Smaller and
  denser than Elfic Forest, it is the second outdoor map a host can switch to.
  """

  alias RetroHexChat.VirtualSpace.Maps.Overworld

  @width 40
  @height 30
  @border 4
  @cave {19, 4}
  @boulder {8, 20}

  @spec definition() :: map()
  def definition do
    decor = decor()
    blocked = MapSet.union(prop_cells(decor), treeline_cells())

    %{
      id: "moss_grove",
      version: 2,
      width: @width,
      height: @height,
      tile_size: 16,
      tilesets: Overworld.tilesets(),
      tiles: Overworld.tiles(),
      ground: "grass",
      spawn: for(y <- 14..15, x <- 18..21, do: %{x: x, y: y, dir: "down"}),
      layers: %{floor: floor_layer(), decor: decor, above: []},
      collision: blocked_rects(blocked),
      zones: [
        %{id: "spawn", kind: "spawn", x: 18, y: 14, w: 4, h: 2},
        %{id: "grove", kind: "common", x: 6, y: 6, w: 28, h: 18}
      ],
      interactables: [],
      seats: [
        %{id: "seat_a", x: 12, y: 12, dir: "down"},
        %{id: "seat_b", x: 27, y: 18, dir: "up"}
      ]
    }
  end

  defp floor_layer do
    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: texture(x, y)
    end
  end

  # Denser mossy scatter than the valley; `:erlang.phash2` avoids banding.
  defp texture(x, y) do
    case :erlang.phash2({x, y}, 22) do
      0 -> "grass_dark"
      1 -> "grass_dark"
      2 -> "flowers"
      3 -> "grass_tuft"
      4 -> "grass_worn"
      _ -> "grass"
    end
  end

  defp decor do
    (treeline() ++
       [%{x: elem(@cave, 0), y: elem(@cave, 1), tile: "cave"}] ++
       [%{x: elem(@boulder, 0), y: elem(@boulder, 1), tile: "boulder"}] ++
       [
         %{x: 28, y: 8, tile: "tree"},
         %{x: 30, y: 10, tile: "tree"},
         %{x: 10, y: 22, tile: "bush"}
       ])
    |> Enum.sort_by(fn %{x: x, y: y} -> {y, x} end)
  end

  defp treeline do
    for x <- 0..(@width - 1)//2,
        y <- 0..(@height - 1)//2,
        x <= @border - 2 or x >= @width - @border or y <= @border - 2 or y >= @height - @border,
        into: [] do
      %{x: x, y: y, tile: "tree"}
    end
  end

  defp prop_cells(decor) do
    for %{x: x, y: y, tile: tile} <- decor,
        %{w: w, h: h} = size(tile),
        dx <- 0..(w - 1),
        dy <- 0..(h - 1),
        into: MapSet.new() do
      {x + dx, y + dy}
    end
  end

  defp treeline_cells do
    for %{x: x, y: y} <- treeline(), dx <- 0..1, dy <- 0..1, into: MapSet.new() do
      {x + dx, y + dy}
    end
  end

  defp size(tile) do
    spec = Elixir.Map.fetch!(Overworld.tiles(), tile)
    %{w: Elixir.Map.get(spec, :w, 1), h: Elixir.Map.get(spec, :h, 1)}
  end

  defp blocked_rects(blocked) do
    for {x, y} <- MapSet.to_list(blocked), do: %{x: x, y: y, w: 1, h: 1, kind: "prop"}
  end
end
