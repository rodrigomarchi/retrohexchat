defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest: a composed overworld village. A tree ring frames the map; the
  main road runs bridge-less from the wild south bank up through the village
  gate, the market square and the well plaza; the river crosses west→east and
  is forded only on the stepping stones; the church + orchard hold the west,
  the farm the east, and south of the river lie the shrine, the campfire, the
  ruined watchtower, the lake, the old graveyard and the witch's camp.

  The layout is authored scene-by-scene in
  `docs/virtual.space.tiles/tools/full_map.py` (semantic intent → deterministic
  autotile → validation) and exported by `tools/export_map.py` as
  `priv/maps/elfic_forest.json`: pure layout (floor tile names, decor in
  painter order, blocked cells) — no pixel data, the client slices the sheets
  at runtime. This module loads it and adds the interactive furniture.
  """

  alias RetroHexChat.VirtualSpace.Maps.Overworld

  @spec definition() :: map()
  def definition do
    data = load()
    ground = data["ground"]

    floor = Enum.map(data["floor"], fn row -> Enum.map(row, &(&1 || ground)) end)

    # The exporter emits decor in painter order (fences, props sorted by
    # {y, x}, then overlay details) — preserve it so overlays stay on top.
    decor =
      Enum.map(data["decor"], fn %{"x" => x, "y" => y, "tile" => tile} ->
        %{x: x, y: y, tile: tile}
      end)

    collision =
      Enum.map(data["blocked"], fn [x, y] -> %{x: x, y: y, w: 1, h: 1, kind: "solid"} end)

    %{
      id: "elfic_forest",
      version: 4,
      width: data["width"],
      height: data["height"],
      tile_size: 16,
      tilesets: Overworld.tilesets(),
      tiles: Overworld.tiles(),
      ground: ground,
      spawn: for(y <- 26..27, x <- 41..44, do: %{x: x, y: y, dir: "down"}),
      layers: %{floor: floor, decor: decor, above: []},
      collision: collision,
      zones: zones(),
      interactables: interactables(),
      seats: seats()
    }
  end

  defp load do
    :retro_hex_chat
    |> :code.priv_dir()
    |> Path.join("maps/elfic_forest.json")
    |> File.read!()
    |> JSON.decode!()
  end

  defp zones do
    [
      %{id: "spawn", kind: "spawn", x: 41, y: 26, w: 4, h: 2},
      %{id: "village", kind: "common", x: 22, y: 8, w: 46, h: 31},
      %{id: "fountain_garden", kind: "meeting", x: 54, y: 20, w: 12, h: 11},
      %{id: "forest_shrine", kind: "meeting", x: 40, y: 50, w: 12, h: 8},
      %{id: "wilds", kind: "common", x: 2, y: 44, w: 88, h: 22}
    ]
  end

  # One pair of seats per bench (market, well plaza, fountain garden,
  # churchyard) — the seat tile is the bench's front row.
  defp seats do
    [
      %{id: "seat_market_a", x: 49, y: 27, dir: "down"},
      %{id: "seat_market_b", x: 51, y: 27, dir: "down"},
      %{id: "seat_well_a", x: 43, y: 10, dir: "down"},
      %{id: "seat_well_b", x: 45, y: 10, dir: "down"},
      %{id: "seat_garden_a", x: 58, y: 29, dir: "down"},
      %{id: "seat_garden_b", x: 60, y: 29, dir: "down"},
      %{id: "seat_church_a", x: 20, y: 27, dir: "down"},
      %{id: "seat_church_b", x: 22, y: 27, dir: "down"}
    ]
  end

  defp interactables do
    [
      %{
        id: "notice_board",
        kind: "board",
        x: 40,
        y: 18,
        title: "Notice board",
        modal: %{kind: "image", asset: "board_menu_v1"}
      }
    ]
  end
end
