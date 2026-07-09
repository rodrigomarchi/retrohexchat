defmodule RetroHexChat.VirtualSpace.Maps.DirectMessageRoom do
  @moduledoc """
  Direct Message Room: a small indoor lounge for private conversations.

  The room is intentionally simple but larger than the viewport: a closed brick
  interior, two clear spawn points, wall-mounted details and one centered
  conversation table. It reuses the shared map protocol and `inner` sheet
  catalog.
  """

  alias RetroHexChat.VirtualSpace.Maps.Catalog

  @width 72
  @height 30
  @top_wall_height 4
  @bottom_wall_start 28

  @floor_tile "floor_checker"
  @rug_tile "dm_green_rug_fill"
  @rug_rect %{ts: "inner", col: 1, row: 8, w: 1, h: 1}
  @rug_area %{x: 31, y: 6, w: 10, h: 5}
  @table_tile "counter_indoor"
  @chair_right_tile "dm_chair_wood_right"
  @chair_right_rect %{ts: "inner", col: 16, row: 4, w: 1, h: 3, flip_x: true}
  @custom_tiles %{
    @rug_tile => @rug_rect,
    @chair_right_tile => @chair_right_rect
  }

  @tile_names ~w(
    wall_brick_brown
    floor_checker
    chair_wood
    counter_indoor
    fireplace_lit
    window_4pane
    painting_night
    sideboard_wood
    shelf_bottles
    plant_potted
    plant_tall
    candle_lit
    door_double_arch
  )

  @spec definition() :: map()
  def definition do
    %{
      id: "direct_message_room",
      version: 1,
      width: @width,
      height: @height,
      tile_size: 16,
      tilesets: Catalog.tilesets(),
      tiles: tiles(),
      ground: @floor_tile,
      spawn: [
        %{x: 32, y: 11, dir: "right"},
        %{x: 39, y: 11, dir: "left"}
      ],
      layers: %{floor: floor_layer(), decor: decor(), above: []},
      labels: [
        %{id: "dm_nameplate", kind: "table_nameplate", x: 33, y: 8, w: 6, h: 1, text: ""}
      ],
      collision: collision(),
      zones: [
        %{id: "dm_room", kind: "private", x: 1, y: 1, w: @width - 2, h: @height - 2},
        %{id: "conversation", kind: "meeting", x: 24, y: 6, w: 16, h: 10}
      ],
      interactables: [],
      seats: []
    }
  end

  defp tiles do
    @tile_names
    |> Catalog.tiles()
    |> Map.merge(@custom_tiles)
  end

  defp floor_layer do
    Enum.map(0..(@height - 1), &floor_row/1)
  end

  defp floor_row(y) do
    Enum.map(0..(@width - 1), &floor_tile(&1, y))
  end

  defp floor_tile(x, y) do
    if in_rect?(x, y, @rug_area), do: @rug_tile, else: @floor_tile
  end

  defp decor do
    wall_tiles() ++
      [
        %{x: 23, y: 1, tile: "window_4pane"},
        %{x: 29, y: 2, tile: "door_double_arch"},
        %{x: 35, y: 3, tile: "fireplace_lit"},
        %{x: 48, y: 1, tile: "painting_night"},
        %{x: 32, y: 2, tile: "candle_lit"},
        %{x: 40, y: 2, tile: "candle_lit"},
        %{x: 50, y: 2, tile: "shelf_bottles"},
        %{x: 20, y: 2, tile: "painting_night"},
        %{x: 18, y: 4, tile: "sideboard_wood"},
        %{x: 19, y: 4, tile: "plant_potted"},
        %{x: 50, y: 4, tile: "sideboard_wood"},
        %{x: 51, y: 4, tile: "plant_potted"},
        %{x: 32, y: 7, tile: "chair_wood"},
        %{x: 39, y: 7, tile: @chair_right_tile},
        %{x: 33, y: 7, tile: @table_tile},
        %{x: 36, y: 7, tile: @table_tile},
        %{x: 29, y: 13, tile: "plant_tall"}
      ]
  end

  defp wall_tiles do
    top =
      for x <- 0..(@width - 1), y <- 0..(@top_wall_height - 1) do
        %{x: x, y: y, tile: "wall_brick_brown"}
      end

    bottom =
      for x <- 0..(@width - 1), y <- @bottom_wall_start..(@height - 1) do
        %{x: x, y: y, tile: "wall_brick_brown"}
      end

    sides =
      for y <- @top_wall_height..(@bottom_wall_start - 1), x <- [0, @width - 1] do
        %{x: x, y: y, tile: "wall_brick_brown"}
      end

    top ++ bottom ++ sides
  end

  defp collision do
    wall_collision() ++
      solid_rects([
        {35, 3, "fireplace_lit"},
        {29, 2, "door_double_arch"},
        {50, 2, "shelf_bottles"},
        {18, 4, "sideboard_wood"},
        {50, 4, "sideboard_wood"},
        {32, 7, "chair_wood"},
        {39, 7, @chair_right_tile},
        {33, 7, @table_tile},
        {36, 7, @table_tile}
      ])
  end

  defp wall_collision do
    top =
      for x <- 0..(@width - 1), y <- 0..(@top_wall_height - 1) do
        {x, y}
      end

    bottom =
      for x <- 0..(@width - 1), y <- @bottom_wall_start..(@height - 1) do
        {x, y}
      end

    sides =
      for y <- @top_wall_height..(@bottom_wall_start - 1), x <- [0, @width - 1] do
        {x, y}
      end

    Enum.map(top ++ bottom ++ sides, fn {x, y} ->
      %{x: x, y: y, w: 1, h: 1, kind: "wall"}
    end)
  end

  defp solid_rects(props) do
    for {x, y, tile} <- props,
        %{w: w, h: h} <- [tile_rect(tile)] do
      %{x: x, y: y, w: w, h: h, kind: "furniture"}
    end
  end

  defp tile_rect(tile), do: Catalog.tile(tile) || Map.fetch!(@custom_tiles, tile)

  defp in_rect?(x, y, %{x: left, y: top, w: width, h: height}) do
    x >= left and x < left + width and y >= top and y < top + height
  end
end
