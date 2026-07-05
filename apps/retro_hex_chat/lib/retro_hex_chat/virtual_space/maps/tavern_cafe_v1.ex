defmodule RetroHexChat.VirtualSpace.Maps.TavernCafeV1 do
  @moduledoc """
  Tavern-cafe map: a fantasy coffeehouse meeting spot, the default virtual
  space. Perimeter walls plus a bar counter block movement; zones split the
  room into spawn, main cafe, meeting side room and quiet corner.
  """

  @width 64
  @height 48

  @spec definition() :: map()
  def definition do
    %{
      id: "tavern_cafe_v1",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      spawn: [
        %{x: 10, y: 12, dir: "down"},
        %{x: 11, y: 12, dir: "down"},
        %{x: 12, y: 12, dir: "down"},
        %{x: 10, y: 13, dir: "down"},
        %{x: 11, y: 13, dir: "down"},
        %{x: 12, y: 13, dir: "down"}
      ],
      layers: %{floor: floor_layer(), decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: 64, h: 1, kind: "wall"},
        %{x: 0, y: 47, w: 64, h: 1, kind: "wall"},
        %{x: 0, y: 1, w: 1, h: 46, kind: "wall"},
        %{x: 63, y: 1, w: 1, h: 46, kind: "wall"},
        %{x: 16, y: 15, w: 6, h: 1, kind: "counter"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 10, y: 12, w: 6, h: 4},
        %{id: "main_cafe", kind: "common", x: 8, y: 8, w: 24, h: 18},
        %{id: "side_room", kind: "meeting", x: 36, y: 8, w: 12, h: 10},
        %{id: "quiet_corner", kind: "quiet", x: 42, y: 24, w: 12, h: 10}
      ],
      interactables: [
        %{
          id: "menu_board",
          kind: "board",
          x: 12,
          y: 10,
          title: "Tavern menu",
          modal: %{kind: "image", asset: "board_menu_v1"}
        },
        %{
          id: "standup_board",
          kind: "board",
          x: 28,
          y: 12,
          title: "Daily",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: [
        %{id: "seat_bar_1", x: 18, y: 14, dir: "up"},
        %{id: "seat_bar_2", x: 19, y: 14, dir: "up"},
        %{id: "seat_table_1_a", x: 24, y: 20, dir: "right"},
        %{id: "seat_table_1_b", x: 26, y: 20, dir: "left"}
      ]
    }
  end

  # Floor layer as a height×width matrix of tile ids: stone-walled perimeter,
  # wood floor throughout, stone in the meeting side room and grass in the
  # quiet corner. Generated so the definition stays readable.
  @side_room %{x0: 36, y0: 8, x1: 47, y1: 17}
  @quiet %{x0: 42, y0: 24, x1: 53, y1: 33}

  defp floor_layer do
    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: floor_tile(x, y)
    end
  end

  defp floor_tile(x, y) do
    cond do
      x == 0 or y == 0 or x == @width - 1 or y == @height - 1 -> "wall_stone"
      within?(x, y, @side_room) -> "floor_stone"
      within?(x, y, @quiet) -> "floor_grass"
      true -> "floor_wood"
    end
  end

  defp within?(x, y, %{x0: x0, y0: y0, x1: x1, y1: y1}) do
    x >= x0 and x <= x1 and y >= y0 and y <= y1
  end
end
