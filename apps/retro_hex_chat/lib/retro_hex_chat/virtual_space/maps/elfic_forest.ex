defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest map: an open grass clearing walled by a thick treeline of bushes
  crowned with round tree canopies, a cabin landmark, a cliff ledge dropping
  into the clearing, a pond, boulders and fallen-log seats. The floor layer
  carries ground and single-tile props over a grass base; multi-tile props
  (cabin, boulder, trees) are decor sprites. Collision blocks the treeline,
  canopies, cliff face, cabin, boulder and pond.
  """

  @width 44
  @height 32

  # Round tree canopies (2x2 decor) placed as a dense ring just inside the bush
  # border, on the forested high ground above the cliff, and in a few clusters.
  @trees [
    # Top forest wall.
    {9, 1},
    {12, 2},
    {15, 1},
    {24, 1},
    {27, 2},
    {33, 1},
    {37, 2},
    # Forested high ground crowning the cliffs.
    {9, 4},
    {12, 5},
    {15, 4},
    {17, 5},
    {23, 5},
    {25, 4},
    {28, 6},
    {31, 4},
    {34, 7},
    {37, 5},
    # Side and bottom treeline.
    {1, 13},
    {2, 18},
    {1, 23},
    {2, 27},
    {41, 14},
    {40, 19},
    {41, 24},
    {40, 27},
    {11, 29},
    {17, 28},
    {24, 29},
    {30, 28},
    {36, 29},
    # Clearing accents.
    {6, 18},
    {38, 17}
  ]

  @house {3, 2}
  @boulder {20, 15}

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
        %{x: 20, y: 20, dir: "down"},
        %{x: 21, y: 20, dir: "down"},
        %{x: 22, y: 20, dir: "down"},
        %{x: 20, y: 21, dir: "down"},
        %{x: 21, y: 21, dir: "down"},
        %{x: 22, y: 21, dir: "down"}
      ],
      layers: %{floor: floor_layer(props), decor: decor(), above: []},
      collision: collision(props),
      zones: [
        %{id: "spawn", kind: "spawn", x: 18, y: 18, w: 8, h: 6},
        %{id: "clearing", kind: "common", x: 4, y: 4, w: 36, h: 24},
        %{id: "grove", kind: "quiet", x: 6, y: 20, w: 10, h: 6},
        %{id: "pondside", kind: "quiet", x: 30, y: 22, w: 8, h: 7}
      ],
      interactables: [
        %{
          id: "notice_board",
          kind: "board",
          x: 24,
          y: 20,
          title: "Forest notice",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: [
        %{id: "grove_log_l", x: 9, y: 24, dir: "up"},
        %{id: "grove_log_m", x: 10, y: 24, dir: "up"},
        %{id: "grove_log_r", x: 11, y: 24, dir: "up"},
        %{id: "pond_log_l", x: 31, y: 27, dir: "up"},
        %{id: "pond_log_m", x: 32, y: 27, dir: "up"}
      ]
    }
  end

  defp props do
    %{}
    |> forest_border()
    # Cliff framing the clearing: the forested high ground drops to the clearing
    # in two stepped ledges.
    |> cliff(3, 7, 20)
    |> cliff(20, 10, 40)
    |> pond(33, 24)
    |> log(9, 24)
    |> log(31, 27)
    |> flower_beds()
  end

  # Multi-tile sprites drawn over the floor: the cabin, a boulder, and the ring
  # of tree canopies.
  defp decor do
    {hx, hy} = @house
    {bx, by} = @boulder

    [%{x: hx, y: hy, tile: "house"}, %{x: bx, y: by, tile: "boulder"}] ++
      Enum.map(@trees, fn {x, y} -> %{x: x, y: y, tile: "tree"} end)
  end

  defp floor_layer(props) do
    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: Elixir.Map.get(props, {x, y}) || "grass"
    end
  end

  # Three-tile-thick band of bushes hugging the border — the forest wall.
  defp forest_border(props) do
    for x <- 0..(@width - 1),
        y <- 0..(@height - 1),
        x < 3 or x >= @width - 3 or y < 3 or y >= @height - 3,
        into: props do
      {{x, y}, "bush"}
    end
  end

  # Horizontal ledge: grass-lip edge on top, then a three-tile rock face
  # (top / mid / base) so it reads clearly as raised ground dropping down.
  defp cliff(props, x0, y, x1) do
    Enum.reduce(x0..x1, props, fn x, acc ->
      acc
      |> Elixir.Map.put({x, y}, "cliff_edge")
      |> Elixir.Map.put({x, y + 1}, "cliff_face")
      |> Elixir.Map.put({x, y + 2}, "cliff_mid")
      |> Elixir.Map.put({x, y + 3}, "cliff_base")
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

  defp flower_beds(props) do
    [{14, 16}, {15, 16}, {14, 17}, {28, 8}, {29, 8}, {17, 24}, {18, 24}, {35, 18}]
    |> Enum.reduce(props, fn {x, y}, acc -> Elixir.Map.put(acc, {x, y}, "flowers") end)
  end

  # Floor-prop collision + the multi-tile decor footprints (cabin walls, boulder,
  # tree bases). Logs, flowers and the cliff-top grass lip stay passable.
  defp collision(props) do
    passable = MapSet.new(["log_l", "log_m", "log_r", "flowers", "cliff_edge"])

    floor =
      for {{x, y}, tile} <- props,
          tile != "grass",
          not MapSet.member?(passable, tile) do
        %{x: x, y: y, w: 1, h: 1, kind: "forest"}
      end

    {hx, hy} = @house
    {bx, by} = @boulder
    trees = Enum.flat_map(@trees, fn {x, y} -> rect(x, y, 2, 2, "tree") end)

    floor ++ house_collision(hx, hy) ++ rect(bx, by, 3, 2, "boulder") ++ trees
  end

  # The cabin's walls (5x5 sprite minus the transparent roof peak).
  defp house_collision(x, y) do
    for dx <- 0..4, dy <- 1..4, do: %{x: x + dx, y: y + dy, w: 1, h: 1, kind: "house"}
  end

  defp rect(x, y, w, h, kind) do
    for dx <- 0..(w - 1), dy <- 0..(h - 1), do: %{x: x + dx, y: y + dy, w: 1, h: 1, kind: kind}
  end
end
