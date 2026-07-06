defmodule RetroHexChat.VirtualSpace.Maps.GuildHallV1 do
  @moduledoc """
  Guild hall map: a stone great-hall for larger gatherings. A long central rug
  runs between two rows of benches up to a raised dais with a notice board.
  """

  @width 64
  @height 48

  @spec definition() :: map()
  def definition do
    %{
      id: "guild_hall_v1",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      spawn: [
        %{x: 30, y: 40, dir: "up"},
        %{x: 31, y: 40, dir: "up"},
        %{x: 32, y: 40, dir: "up"},
        %{x: 33, y: 40, dir: "up"},
        %{x: 30, y: 41, dir: "up"},
        %{x: 33, y: 41, dir: "up"}
      ],
      layers: %{floor: floor_layer(), decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: @width, h: 1, kind: "wall"},
        %{x: 0, y: @height - 1, w: @width, h: 1, kind: "wall"},
        %{x: 0, y: 1, w: 1, h: @height - 2, kind: "wall"},
        %{x: @width - 1, y: 1, w: 1, h: @height - 2, kind: "wall"},
        %{x: 28, y: 8, w: 8, h: 1, kind: "dais"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 28, y: 38, w: 8, h: 6},
        %{id: "great_hall", kind: "common", x: 8, y: 10, w: 48, h: 30},
        %{id: "dais", kind: "meeting", x: 26, y: 4, w: 12, h: 6}
      ],
      interactables: [
        %{
          id: "notice_board",
          kind: "board",
          x: 32,
          y: 6,
          title: "Guild notices",
          modal: %{kind: "image", asset: "board_menu_v1"}
        }
      ],
      seats: [
        %{id: "bench_l_1", x: 24, y: 20, dir: "right"},
        %{id: "bench_l_2", x: 24, y: 24, dir: "right"},
        %{id: "bench_r_1", x: 40, y: 20, dir: "left"},
        %{id: "bench_r_2", x: 40, y: 24, dir: "left"}
      ]
    }
  end

  # Stone hall with a wooden central runner from spawn to the dais.
  defp floor_layer do
    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: floor_tile(x, y)
    end
  end

  defp floor_tile(x, y) do
    cond do
      x == 0 or y == 0 or x == @width - 1 or y == @height - 1 -> "wall_stone"
      x in 30..33 -> "floor_wood"
      true -> "floor_stone"
    end
  end
end
