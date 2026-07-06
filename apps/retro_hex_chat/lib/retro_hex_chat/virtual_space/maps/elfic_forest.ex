defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest map: an open grass valley walled by a dense treeline, entered
  through a cave passage in a cliff. Cliff ledges drop the forested high ground
  into the valley, a pond pools at the base of the lower cliff, and a cabin sits
  on the upper-left ground. The floor layer carries ground and single-tile props
  over a grass base; multi-tile props (cabin, boulder, trees, cave) are decor
  sprites. Collision blocks the treeline, canopies, cliff faces, cabin, boulder
  and pond, leaving the cave mouth and cliff-top lip walkable.
  """

  @width 44
  @height 32

  @house {3, 2}
  @boulder {33, 14}
  @cave_x 15

  # Rects (x0, y0, x1, y1 inclusive) kept clear of tree canopies: the cabin, the
  # spawn clearing, the two cliff bands, the pond, the boulder and the cave
  # passage.
  @keepout [
    {1, 1, 8, 7},
    {16, 15, 27, 23},
    {3, 8, 31, 12},
    {23, 21, 41, 26},
    {29, 25, 34, 30},
    {32, 13, 36, 16},
    {@cave_x - 1, 7, @cave_x + 1, 12}
  ]

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
        %{x: 20, y: 19, dir: "down"},
        %{x: 21, y: 19, dir: "down"},
        %{x: 22, y: 19, dir: "down"},
        %{x: 20, y: 20, dir: "down"},
        %{x: 21, y: 20, dir: "down"},
        %{x: 22, y: 20, dir: "down"}
      ],
      layers: %{floor: floor_layer(props), decor: decor(), above: []},
      collision: collision(props),
      zones: [
        %{id: "spawn", kind: "spawn", x: 18, y: 17, w: 8, h: 5},
        %{id: "valley", kind: "common", x: 4, y: 13, w: 36, h: 14},
        %{id: "highground", kind: "quiet", x: 4, y: 4, w: 26, h: 4},
        %{id: "pondside", kind: "quiet", x: 28, y: 26, w: 8, h: 4}
      ],
      interactables: [
        %{
          id: "notice_board",
          kind: "board",
          x: 25,
          y: 18,
          title: "Forest notice",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: [
        %{id: "valley_log_l", x: 9, y: 16, dir: "up"},
        %{id: "valley_log_m", x: 10, y: 16, dir: "up"},
        %{id: "valley_log_r", x: 11, y: 16, dir: "up"},
        %{id: "pond_log_l", x: 24, y: 27, dir: "up"},
        %{id: "pond_log_m", x: 25, y: 27, dir: "up"}
      ]
    }
  end

  defp props do
    %{}
    |> forest_border()
    # Top cliff: forested high ground dropping into the valley, split by a cave
    # passage; lower cliff: the ledge the pond pools under.
    |> cliff(4, 8, @cave_x - 2)
    |> cliff(@cave_x + 2, 8, 30)
    |> cliff(24, 22, 40)
    |> pond(29, 26)
    |> log(9, 16)
    |> log(23, 27)
    |> flower_beds()
  end

  # Cabin, boulder, cave mouth and the dense ring of tree canopies.
  defp decor do
    {hx, hy} = @house
    {bx, by} = @boulder

    [
      %{x: hx, y: hy, tile: "house"},
      %{x: bx, y: by, tile: "boulder"},
      %{x: @cave_x, y: 9, tile: "cave"}
    ] ++ Enum.map(tree_positions(), fn {x, y} -> %{x: x, y: y, tile: "tree"} end)
  end

  # A dense two-deep ring of canopies crowning the border, plus a crown on the
  # high ground and a few valley clusters — everything clear of the keepout rects.
  defp tree_positions do
    ring =
      Enum.map(3..40//2, &{&1, 1}) ++
        Enum.map(3..40//2, &{&1, 29}) ++
        Enum.map(3..28//2, &{1, &1}) ++
        Enum.map(3..28//2, &{41, &1})

    inner =
      Enum.map(6..37//4, &{&1, 3}) ++
        Enum.map(7..26//4, &{3, &1}) ++
        Enum.map(7..26//4, &{39, &1})

    crown = [{6, 5}, {10, 5}, {20, 5}, {24, 5}, {28, 5}, {12, 13}, {29, 13}]
    clusters = [{7, 24}, {14, 25}, {20, 26}, {37, 22}, {6, 20}, {35, 19}]

    (ring ++ inner ++ crown ++ clusters)
    |> Enum.uniq()
    |> Enum.reject(&in_keepout?/1)
  end

  # A 2x2 canopy at {x, y} clears the keepout only if it overlaps no rect.
  defp in_keepout?({x, y}) do
    Enum.any?(@keepout, fn {x0, y0, x1, y1} ->
      x + 1 >= x0 and x <= x1 and y + 1 >= y0 and y <= y1
    end)
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
    [{16, 15}, {17, 15}, {13, 18}, {27, 15}, {28, 15}, {19, 24}, {32, 20}, {8, 22}]
    |> Enum.reduce(props, fn {x, y}, acc -> Elixir.Map.put(acc, {x, y}, "flowers") end)
  end

  # Floor-prop collision + the decor footprints (cabin, boulder, tree bases).
  # Logs, flowers, the cliff-top lip and the cave mouth stay passable.
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
    trees = Enum.flat_map(tree_positions(), fn {x, y} -> rect(x, y, 2, 2, "tree") end)

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
