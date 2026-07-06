defmodule RetroHexChat.VirtualSpace.Maps.GardenCampV1 do
  @moduledoc """
  Garden camp map: an open-air campfire clearing among hedges. Grass throughout,
  a stone patio around the fire, log seats and a wooden signpost board.
  """

  @width 64
  @height 48

  @spec definition() :: map()
  def definition do
    %{
      id: "garden_camp_v1",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      spawn: [
        %{x: 20, y: 20, dir: "down"},
        %{x: 21, y: 20, dir: "down"},
        %{x: 22, y: 20, dir: "down"},
        %{x: 23, y: 20, dir: "down"},
        %{x: 20, y: 21, dir: "down"},
        %{x: 23, y: 21, dir: "down"}
      ],
      layers: %{floor: floor_layer(), decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: @width, h: 1, kind: "hedge"},
        %{x: 0, y: @height - 1, w: @width, h: 1, kind: "hedge"},
        %{x: 0, y: 1, w: 1, h: @height - 2, kind: "hedge"},
        %{x: @width - 1, y: 1, w: 1, h: @height - 2, kind: "hedge"},
        %{x: 31, y: 24, w: 2, h: 2, kind: "fire"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 18, y: 18, w: 8, h: 6},
        %{id: "clearing", kind: "common", x: 8, y: 8, w: 48, h: 32},
        %{id: "firepit", kind: "meeting", x: 26, y: 20, w: 12, h: 12}
      ],
      interactables: [
        %{
          id: "signpost",
          kind: "board",
          x: 14,
          y: 12,
          title: "Trail signpost",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: [
        %{id: "log_n", x: 32, y: 22, dir: "down"},
        %{id: "log_s", x: 32, y: 28, dir: "up"},
        %{id: "log_w", x: 28, y: 25, dir: "right"},
        %{id: "log_e", x: 36, y: 25, dir: "left"}
      ]
    }
  end

  # Grass clearing with a stone patio ring around the central firepit.
  defp floor_layer do
    patio = %{x0: 28, y0: 22, x1: 36, y1: 28}

    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: floor_tile(x, y, patio)
    end
  end

  defp floor_tile(x, y, patio) do
    cond do
      x == 0 or y == 0 or x == @width - 1 or y == @height - 1 -> "wall_stone"
      within?(x, y, patio) -> "floor_stone"
      true -> "floor_grass"
    end
  end

  defp within?(x, y, %{x0: x0, y0: y0, x1: x1, y1: y1}) do
    x >= x0 and x <= x1 and y >= y0 and y <= y1
  end
end
