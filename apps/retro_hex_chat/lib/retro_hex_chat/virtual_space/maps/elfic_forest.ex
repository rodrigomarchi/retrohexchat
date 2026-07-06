defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest map: a grass clearing framed by a dense treeline of bushes and
  layered tree canopies, terraced by low cliff ledges, with fallen-log seats, a
  pond and scattered boulders. The floor layer carries ground and single-tile
  props over a grass base; collision blocks the treeline, canopies, cliff faces,
  boulders and pond.
  """

  @width 44
  @height 32

  @spec definition() :: map()
  def definition do
    props = props()

    %{
      id: "elfic_forest",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      ground: "grass",
      spawn: [
        %{x: 20, y: 18, dir: "down"},
        %{x: 21, y: 18, dir: "down"},
        %{x: 22, y: 18, dir: "down"},
        %{x: 20, y: 19, dir: "down"},
        %{x: 21, y: 19, dir: "down"},
        %{x: 22, y: 19, dir: "down"}
      ],
      layers: %{
        floor: floor_layer(props),
        decor: [%{x: 4, y: 3, tile: "house"}, %{x: 16, y: 9, tile: "boulder"}],
        above: []
      },
      collision: collision(props) ++ house_collision(4, 3) ++ rect(16, 9, 3, 2),
      zones: [
        %{id: "spawn", kind: "spawn", x: 18, y: 16, w: 8, h: 6},
        %{id: "clearing", kind: "common", x: 4, y: 4, w: 36, h: 24},
        %{id: "grove", kind: "quiet", x: 5, y: 22, w: 10, h: 6},
        %{id: "pondside", kind: "quiet", x: 30, y: 22, w: 8, h: 7}
      ],
      interactables: [
        %{
          id: "notice_board",
          kind: "board",
          x: 22,
          y: 14,
          title: "Forest notice",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: [
        %{id: "grove_log_l", x: 7, y: 24, dir: "up"},
        %{id: "grove_log_m", x: 8, y: 24, dir: "up"},
        %{id: "grove_log_r", x: 9, y: 24, dir: "up"},
        %{id: "pond_log_l", x: 34, y: 26, dir: "up"},
        %{id: "pond_log_m", x: 35, y: 26, dir: "up"}
      ]
    }
  end

  defp props do
    %{}
    |> treeline()
    # Cliff cascade: stepped ledges (grass-lip top, rock face + base) that
    # snake down across the clearing.
    |> cliff(10, 7, 21)
    |> cliff(20, 10, 31)
    |> cliff(31, 13, 40)
    # Tree clusters: overlapping canopies for dense masses.
    |> grove(11, 3, 3)
    |> grove(33, 3, 2)
    |> grove(37, 17, 2)
    |> grove(3, 14, 3)
    |> grove(6, 26, 3)
    |> grove(29, 26, 2)
    |> grove(20, 4, 1)
    |> grove(15, 23, 2)
    |> grove(40, 9, 1)
    |> pond(32, 23)
    |> log(7, 24)
    |> log(34, 26)
    |> boulders()
    |> flower_beds()
  end

  defp floor_layer(props) do
    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: Elixir.Map.get(props, {x, y}) || "grass"
    end
  end

  # Two-tile-thick band of bushes hugging the border.
  defp treeline(props) do
    for x <- 0..(@width - 1),
        y <- 0..(@height - 1),
        x < 2 or x >= @width - 2 or y < 2 or y >= @height - 2,
        into: props do
      {{x, y}, "bush"}
    end
  end

  # `count` layered 2x3 canopies placed left-to-right, overlapping by one tile.
  defp grove(props, x, y, count) do
    Enum.reduce(0..(count - 1), props, fn i, acc -> tree(acc, x + i * 2, y + rem(i, 2)) end)
  end

  defp tree(props, x, y) do
    %{
      {x, y} => "tree_tl",
      {x + 1, y} => "tree_tr",
      {x, y + 1} => "tree_ml",
      {x + 1, y + 1} => "tree_mr",
      {x, y + 2} => "tree_bl",
      {x + 1, y + 2} => "tree_br"
    }
    |> Enum.into(props)
  end

  # Horizontal ledge: grass-lip edge on top, rock face + base below.
  defp cliff(props, x0, y, x1) do
    Enum.reduce(x0..x1, props, fn x, acc ->
      acc
      |> Elixir.Map.put({x, y}, "cliff_edge")
      |> Elixir.Map.put({x, y + 1}, "cliff_face")
      |> Elixir.Map.put({x, y + 2}, "cliff_base")
    end)
  end

  defp pond(props, x, y) do
    [
      {0, 0, "pond_tl"},
      {1, 0, "pond_tm"},
      {2, 0, "pond_tr"},
      {0, 1, "pond_ml"},
      {1, 1, "pond_c"},
      {2, 1, "pond_mr"},
      {0, 2, "pond_bl"},
      {1, 2, "pond_bm"},
      {2, 2, "pond_br"}
    ]
    |> Enum.reduce(props, fn {dx, dy, tile}, acc ->
      Elixir.Map.put(acc, {x + dx, y + dy}, tile)
    end)
  end

  defp log(props, x, y) do
    props
    |> Elixir.Map.put({x, y}, "log_l")
    |> Elixir.Map.put({x + 1, y}, "log_m")
    |> Elixir.Map.put({x + 2, y}, "log_r")
  end

  defp boulders(props) do
    [{16, 9}, {24, 26}, {12, 28}, {38, 26}, {19, 27}]
    |> Enum.reduce(props, fn {x, y}, acc ->
      acc |> Elixir.Map.put({x, y}, "rock") |> Elixir.Map.put({x + 1, y}, "rock_s")
    end)
  end

  # A few dense flower clusters instead of scattering flowers everywhere.
  defp flower_beds(props) do
    [
      {12, 15},
      {13, 15},
      {12, 16},
      {13, 16},
      {30, 6},
      {31, 6},
      {30, 7},
      {23, 25},
      {24, 25},
      {23, 26}
    ]
    |> Enum.reduce(props, fn {x, y}, acc -> Elixir.Map.put(acc, {x, y}, "flowers") end)
  end

  # Blocks the cabin's walls (its 5x5 sprite minus the transparent roof peak).
  defp house_collision(x, y) do
    for dx <- 0..4, dy <- 1..4, do: %{x: x + dx, y: y + dy, w: 1, h: 1, kind: "house"}
  end

  defp rect(x, y, w, h) do
    for dx <- 0..(w - 1), dy <- 0..(h - 1), do: %{x: x + dx, y: y + dy, w: 1, h: 1, kind: "prop"}
  end

  defp collision(props) do
    passable = MapSet.new(["log_l", "log_m", "log_r", "flowers", "cliff_edge"])

    for {{x, y}, tile} <- props,
        tile != "grass",
        not MapSet.member?(passable, tile) do
      %{x: x, y: y, w: 1, h: 1, kind: "forest"}
    end
  end
end
