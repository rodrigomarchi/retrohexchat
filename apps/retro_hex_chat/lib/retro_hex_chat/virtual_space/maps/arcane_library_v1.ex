defmodule RetroHexChat.VirtualSpace.Maps.ArcaneLibraryV1 do
  @moduledoc """
  Arcane library map: a hushed hall of bookshelves and study desks. A quiet
  reading zone sits apart from the common stacks, with a catalogue board near
  the entrance.
  """

  @width 64
  @height 48

  @spec definition() :: map()
  def definition do
    %{
      id: "arcane_library_v1",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      spawn: [
        %{x: 8, y: 40, dir: "up"},
        %{x: 9, y: 40, dir: "up"},
        %{x: 10, y: 40, dir: "up"},
        %{x: 11, y: 40, dir: "up"},
        %{x: 8, y: 41, dir: "up"},
        %{x: 11, y: 41, dir: "up"}
      ],
      layers: %{floor: floor_layer(), decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: @width, h: 1, kind: "wall"},
        %{x: 0, y: @height - 1, w: @width, h: 1, kind: "wall"},
        %{x: 0, y: 1, w: 1, h: @height - 2, kind: "wall"},
        %{x: @width - 1, y: 1, w: 1, h: @height - 2, kind: "wall"},
        %{x: 20, y: 10, w: 1, h: 20, kind: "shelf"},
        %{x: 40, y: 10, w: 1, h: 20, kind: "shelf"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 6, y: 38, w: 8, h: 6},
        %{id: "stacks", kind: "common", x: 8, y: 8, w: 48, h: 26},
        %{id: "quiet_reading", kind: "quiet", x: 44, y: 34, w: 12, h: 10}
      ],
      interactables: [
        %{
          id: "catalogue_board",
          kind: "board",
          x: 14,
          y: 8,
          title: "Card catalogue",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: [
        %{id: "desk_1", x: 12, y: 14, dir: "down"},
        %{id: "desk_2", x: 12, y: 18, dir: "down"},
        %{id: "reading_1", x: 48, y: 38, dir: "up"},
        %{id: "reading_2", x: 51, y: 38, dir: "up"}
      ]
    }
  end

  # Wood floor throughout, with a grass reading nook in the quiet corner.
  defp floor_layer do
    quiet = %{x0: 44, y0: 34, x1: 55, y1: 43}

    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: floor_tile(x, y, quiet)
    end
  end

  defp floor_tile(x, y, quiet) do
    cond do
      x == 0 or y == 0 or x == @width - 1 or y == @height - 1 -> "wall_stone"
      within?(x, y, quiet) -> "floor_grass"
      true -> "floor_wood"
    end
  end

  defp within?(x, y, %{x0: x0, y0: y0, x1: x1, y1: y1}) do
    x >= x0 and x <= x1 and y >= y0 and y <= y1
  end
end
