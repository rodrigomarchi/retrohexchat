defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest map: a forest basin traced from the reference overworld. A
  `@mask_rows` bitmap marks the forested high ground; the open valley is
  everything else. A small autotiler reads the mask and terraces the boundary —
  a grass lip on the high edge, a rock face stepping down (face/mid/base) into
  the valley, and vertical side faces where a shelf turns — so the cliffs snake
  and step exactly where the mask does. High ground renders as dense forest
  (bush undergrowth crowned by canopies); the valley is open grass broken up by
  dark-grass patches, clover and a worn dirt trail. A cabin sits on the upper-
  left shelf, a pond pools at the base of the lower cliff, and logs, a boulder
  and scattered rocks are placed on the shelves and clearings they belong to.
  """

  @width 50
  @height 36

  @mask_rows [
    "##################################################",
    "##################################################",
    "##..######......############.....#################",
    "##..######......############.....#################",
    "##..######...........#######.......###############",
    "##..######..............####.......###############",
    "##...........................###...###############",
    "##...........................###...###############",
    "##...........................###.......###########",
    "##.....................................###########",
    "##.....................................###########",
    "##.........#####.......................###########",
    "##.........#####.......................###########",
    "################........................##########",
    "################........................##########",
    "################........................##########",
    "##......................................##########",
    "##..........................................######",
    "##............###............................#####",
    "##............###.............................####",
    "##............###.............................####",
    "##.........######.............................####",
    "##.........######........................####.####",
    "##.........######.....................#######...##",
    "##....................................#########.##",
    "##..............................####..############",
    "##..............................####.#############",
    "##..............................###########..#####",
    "##........................#################...####",
    "##........................#############.........##",
    "##........................#########.............##",
    "##..............................................##",
    "##.....#####.................................#####",
    "##.....#####.................................#####",
    "##################################################",
    "##################################################"
  ]

  # Open-grass shelf around the cabin (kept clear of forest); its south edge is
  # a cliff into the valley.
  @cabin_shelf {2, 0, 10, 6}
  @house {4, 1}
  @boulder {30, 6}

  # Pond region (x, y, w, h) at the base of the lower cliff, nine-sliced from the
  # pond tiles.
  @pond_x 25
  @pond_y 31
  @pond_w 7
  @pond_h 3

  # Logs on ledges / clearings — passable benches; rocks trail the edges.
  @logs [{21, 20}, {8, 16}, {33, 25}]
  @rock_spots [
    {6, 15, "rock"},
    {24, 17, "rock"},
    {9, 18, "rock_s"},
    {5, 12, "rock_s"},
    {22, 24, "rock_s"},
    {30, 24, "rock_s"},
    {16, 12, "rock_s"},
    {35, 10, "rock_s"},
    {12, 27, "rock_s"},
    {27, 27, "rock_s"}
  ]
  @valley_trees [
    {8, 9},
    {21, 8},
    {12, 25},
    {28, 12},
    {9, 22},
    {26, 22},
    {18, 28},
    {6, 27},
    {31, 15}
  ]

  @spec definition() :: map()
  def definition do
    floor = floor_layer()
    logs = Enum.filter(@logs, fn {x, y} -> log_fits?(floor, x, y) end)

    %{
      id: "elfic_forest",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      ground: "grass",
      spawn: [
        %{x: 18, y: 17, dir: "down"},
        %{x: 19, y: 17, dir: "down"},
        %{x: 20, y: 17, dir: "down"},
        %{x: 18, y: 18, dir: "down"},
        %{x: 19, y: 18, dir: "down"},
        %{x: 20, y: 18, dir: "down"}
      ],
      layers: %{floor: floor, decor: decor(floor, logs), above: []},
      collision: collision(floor),
      zones: [
        %{id: "spawn", kind: "spawn", x: 16, y: 16, w: 8, h: 4},
        %{id: "valley", kind: "common", x: 3, y: 9, w: 22, h: 14},
        %{id: "highground", kind: "quiet", x: 4, y: 1, w: 6, h: 4},
        %{id: "pondside", kind: "quiet", x: 24, y: 28, w: 10, h: 3}
      ],
      interactables: [
        %{
          id: "notice_board",
          kind: "board",
          x: 22,
          y: 16,
          title: "Forest notice",
          modal: %{kind: "image", asset: "board_daily_v1"}
        }
      ],
      seats: seats(logs)
    }
  end

  defp seats(logs) do
    for {x, y} <- logs, {sx, i} <- Enum.with_index([x, x + 1, x + 2]) do
      %{id: "log_#{x}_#{y}_#{i}", x: sx, y: y, dir: "down"}
    end
  end

  defp log_fits?(floor, x, y) do
    Enum.all?([x, x + 1, x + 2], fn cx -> ground?(floor, cx, y) end)
  end

  # ── Floor ─────────────────────────────────────────────────────────

  defp floor_layer do
    for y <- 0..(@height - 1) do
      for x <- 0..(@width - 1), do: floor_cell(x, y)
    end
  end

  defp floor_cell(x, y) do
    cond do
      pond?(x, y) -> pond_tile(x, y)
      high?(x, y) -> high_tile(x, y)
      true -> low_tile(x, y)
    end
  end

  # A high cell drops a grass lip on its southern edge, is open grass on the
  # cabin shelf, and forested (bush undergrowth) everywhere else.
  defp high_tile(x, y) do
    cond do
      not high?(x, y + 1) -> "cliff_edge"
      shelf?(x, y) -> "grass"
      true -> "bush"
    end
  end

  # A low cell is a cliff face under a terrace, otherwise valley ground textured
  # with the dirt trail, dark-grass patches and clover.
  defp low_tile(x, y) do
    cond do
      face = face_tile(x, y) -> face
      path?(x, y) -> "dirt"
      dark?(x, y) -> "grass_dark"
      clover?(x, y) -> "flowers"
      true -> "grass"
    end
  end

  defp high?(x, y) do
    if x < 0 or y < 0 or x >= @width or y >= @height do
      false
    else
      :binary.at(Enum.at(@mask_rows, y), x) == ?#
    end
  end

  defp shelf?(x, y) do
    {x0, y0, x1, y1} = @cabin_shelf
    x in x0..x1 and y in y0..y1
  end

  # The autotiler for a low cell: depth below the terrace selects face → mid →
  # base, and an east/west high neighbour draws a vertical side face.
  defp face_tile(x, y) do
    cond do
      high?(x, y - 1) -> "cliff_face"
      high?(x, y - 2) -> "cliff_mid"
      high?(x, y - 3) -> "cliff_base"
      high?(x - 1, y) or high?(x + 1, y) -> "cliff_face"
      true -> nil
    end
  end

  # ── Pond (nine-slice) ─────────────────────────────────────────────

  defp pond?(x, y) do
    x in @pond_x..(@pond_x + @pond_w - 1) and y in @pond_y..(@pond_y + @pond_h - 1)
  end

  defp pond_tile(x, y) do
    v = band(y - @pond_y, @pond_h, "t", "b")
    h = band(x - @pond_x, @pond_w, "l", "r")
    if v == "m" and h == "m", do: "pond_c", else: "pond_" <> v <> h
  end

  defp band(0, _size, lo, _hi), do: lo
  defp band(i, size, _lo, hi) when i == size - 1, do: hi
  defp band(_i, _size, _lo, _hi), do: "m"

  # ── Ground texture (valley only) ──────────────────────────────────

  # A worn dirt trail dropping from the cabin shelf into the valley.
  defp path?(x, y), do: x == 8 and y in 6..14

  # Dark-grass seeds grown into soft 2x2 blobs so patches read as rounded areas,
  # not single specks — the valley's main texture break.
  defp dark?(x, y) do
    dark_seed?(x, y) or dark_seed?(x - 1, y) or dark_seed?(x, y - 1) or dark_seed?(x - 1, y - 1)
  end

  defp dark_seed?(x, y), do: rem(x * 7 + y * 13, 15) == 0
  defp clover?(x, y), do: rem(x * 5 + y * 11, 19) == 0

  # ── Decor: cabin, boulder, forest canopies, logs, rocks ───────────

  defp decor(floor, logs) do
    {hx, hy} = @house
    {bx, by} = @boulder

    canopies = Enum.map(tree_positions(), fn {x, y} -> %{x: x, y: y, tile: "tree"} end)
    log_props = Enum.flat_map(logs, fn {x, y} -> log_decor(x, y) end)

    [%{x: hx, y: hy, tile: "house"}, %{x: bx, y: by, tile: "boulder"}] ++
      canopies ++ log_props ++ rocks(floor)
  end

  defp log_decor(x, y) do
    [
      %{x: x, y: y, tile: "log_l"},
      %{x: x + 1, y: y, tile: "log_m"},
      %{x: x + 2, y: y, tile: "log_r"}
    ]
  end

  # Canopies fill the high ground on a 2-tile grid wherever the whole 2x2
  # footprint is forest, plus a few lone valley clumps — dense at the edges,
  # open in the middle.
  defp tree_positions do
    forest =
      for y <- 0..(@height - 2)//2,
          x <- 0..(@width - 2)//2,
          forest_tile?(x, y),
          do: {x, y}

    forest ++ Enum.filter(@valley_trees, fn {x, y} -> not high?(x, y) end)
  end

  defp forest_tile?(x, y) do
    high?(x, y) and high?(x + 1, y) and high?(x, y + 1) and high?(x + 1, y + 1) and
      not shelf?(x, y)
  end

  defp rocks(floor) do
    for {x, y, tile} <- @rock_spots, ground?(floor, x, y), do: %{x: x, y: y, tile: tile}
  end

  defp ground?(floor, x, y) do
    tile = floor |> Enum.at(y) |> Enum.at(x)
    tile in ~w(grass grass_dark dirt flowers)
  end

  # ── Collision ─────────────────────────────────────────────────────

  defp collision(floor) do
    tiles =
      for {row, y} <- Enum.with_index(floor),
          {tile, x} <- Enum.with_index(row),
          blocked_tile?(tile) do
        %{x: x, y: y, w: 1, h: 1, kind: "forest"}
      end

    {hx, hy} = @house
    {bx, by} = @boulder
    trees = Enum.flat_map(tree_positions(), fn {x, y} -> rect(x, y, 2, 2, "tree") end)

    tiles ++ house_collision(hx, hy) ++ rect(bx, by, 3, 2, "boulder") ++ trees
  end

  defp blocked_tile?(tile) do
    tile == "bush" or
      (String.starts_with?(tile, "cliff_") and tile != "cliff_edge") or
      String.starts_with?(tile, "pond_")
  end

  defp house_collision(x, y) do
    for dx <- 0..4, dy <- 1..4, do: %{x: x + dx, y: y + dy, w: 1, h: 1, kind: "house"}
  end

  defp rect(x, y, w, h, kind) do
    for dx <- 0..(w - 1), dy <- 0..(h - 1), do: %{x: x + dx, y: y + dy, w: 1, h: 1, kind: kind}
  end
end
