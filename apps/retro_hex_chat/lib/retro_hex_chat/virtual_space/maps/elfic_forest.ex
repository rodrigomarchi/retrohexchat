defmodule RetroHexChat.VirtualSpace.Maps.ElficForest do
  @moduledoc """
  Elfic Forest: the reference overworld reproduced faithfully. The layout —
  organic tree clumps, the winding cliff terraces, the pond and the cabin — is
  derived from the reference screenshot by `gfx/tools/derive_map.py` (classify
  the image into a semantic grid, then autotile it into our sheet tiles) and
  ships as `priv/maps/elfic_forest.json`. That file is pure *layout* (tile names,
  prop positions and blocked cells) — no pixel data — so the client still slices
  `overworld.png` at runtime.

  This module loads that layout and adds the interactive furniture (spawn, zones,
  seats, board) in the open central plaza the derivation keeps clear.
  """

  alias RetroHexChat.VirtualSpace.Maps.Overworld

  @spec definition() :: map()
  def definition do
    data = load()
    ground = data["ground"]

    floor = Enum.map(data["floor"], fn row -> Enum.map(row, &(&1 || ground)) end)

    decor =
      data["decor"]
      |> Enum.map(fn %{"x" => x, "y" => y, "tile" => tile} -> %{x: x, y: y, tile: tile} end)
      |> Enum.sort_by(fn %{x: x, y: y} -> {y, x} end)

    collision =
      Enum.map(data["blocked"], fn [x, y] -> %{x: x, y: y, w: 1, h: 1, kind: "solid"} end)

    %{
      id: "elfic_forest",
      version: 3,
      width: data["width"],
      height: data["height"],
      tile_size: 16,
      tilesets: Overworld.tilesets(),
      tiles: Overworld.tiles(),
      ground: ground,
      spawn: for(y <- 32..33, x <- 30..33, do: %{x: x, y: y, dir: "down"}),
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

  # The plaza carved open at grid (26..35, 30..37) hosts the interactive furniture.
  defp zones do
    [
      %{id: "spawn", kind: "spawn", x: 30, y: 32, w: 4, h: 2},
      %{id: "valley", kind: "common", x: 16, y: 20, w: 48, h: 28},
      %{id: "cabin_terrace", kind: "meeting", x: 6, y: 1, w: 12, h: 9}
    ]
  end

  defp seats do
    [
      %{id: "seat_log_a", x: 33, y: 34, dir: "down"},
      %{id: "seat_log_b", x: 35, y: 34, dir: "down"}
    ]
  end

  defp interactables do
    [
      %{
        id: "notice_board",
        kind: "board",
        x: 30,
        y: 30,
        title: "Notice board",
        modal: %{kind: "image", asset: "board_menu_v1"}
      }
    ]
  end
end
