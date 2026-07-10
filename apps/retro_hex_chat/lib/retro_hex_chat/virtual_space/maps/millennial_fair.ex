defmodule RetroHexChat.VirtualSpace.Maps.MillennialFair do
  @moduledoc """
  Millennial Fair (Leene Square): the lively festival plaza behind every channel.

  A bustling cobblestone square ringed by lawn — Leene's Bell swinging in its
  belfry at the centre, Lucca's Telepod crackling with electricity, Norstein
  Bekkler's striped game tent, Melchior's weapon stall, refreshment carts, a
  rippling fountain, paper lanterns, trees and a welcome arch. The multi-user
  social hub, in deliberate contrast to the intimate cosmic End of Time DM. The
  vibe borrows the Chrono Trigger opening festival.

  Authored by `virtual.space/tools/author_fair.py`, which packs the PixelLab art
  into `/images/space/millennialfair.png` and emits the layout (autotiled plaza
  floor, decor, collision, spawns, and the tile `vocab` with animated
  `frames`/`period_ms`) as `priv/maps/millennial_fair.json`. This module loads
  that JSON and shapes it into the shared map protocol — the client slices the
  sheet at runtime. See `virtual.space/SCENES.md` and `ANIMATIONS.md`.
  """

  @sheet "millennialfair"

  @spec definition() :: map()
  def definition do
    data = load()

    %{
      id: "millennial_fair",
      version: 1,
      width: data["width"],
      height: data["height"],
      tile_size: data["tile_size"],
      tilesets: [
        %{id: @sheet, src: "/images/space/#{@sheet}.png", tile: 16, columns: data["columns"]}
      ],
      tiles: tiles(data),
      ground: data["ground"],
      spawn: Enum.map(data["spawn"], &%{x: &1["x"], y: &1["y"], dir: &1["dir"]}),
      layers: %{floor: data["floor"], decor: decor(data), above: []},
      labels:
        Enum.map(data["labels"], fn l ->
          %{
            id: l["id"],
            kind: l["kind"],
            x: l["x"],
            y: l["y"],
            w: l["w"],
            h: l["h"],
            text: l["text"]
          }
        end),
      collision:
        Enum.map(
          data["collision"],
          &%{x: &1["x"], y: &1["y"], w: &1["w"], h: &1["h"], kind: &1["kind"]}
        ),
      zones: zones(),
      interactables: interactables(),
      seats: seats()
    }
  end

  # A lone joiner lands in the western half (the "gate"); crossing the centre
  # line enters the main "plaza".
  defp zones do
    [
      %{id: "spawn", kind: "spawn", x: 0, y: 0, w: 26, h: 34},
      %{id: "plaza", kind: "common", x: 26, y: 0, w: 26, h: 34}
    ]
  end

  # Every fair bench is sittable — the seat tile is the bench's front row.
  defp seats do
    [
      %{id: "seat_bench_a", x: 43, y: 22, dir: "down"},
      %{id: "seat_bench_b", x: 21, y: 20, dir: "down"},
      %{id: "seat_bench_c", x: 29, y: 20, dir: "down"},
      %{id: "seat_bench_d", x: 21, y: 11, dir: "down"},
      %{id: "seat_bench_e", x: 29, y: 11, dir: "down"}
    ]
  end

  # The fairground notice board (at the bulletin-board prop) opens the board
  # menu — the one interactable ported from the old channel scene.
  defp interactables do
    [
      %{
        id: "notice_board",
        kind: "board",
        x: 7,
        y: 22,
        title: "Notice board",
        modal: %{kind: "image", asset: "board_menu_v1"}
      }
    ]
  end

  # Optional per-tile keys the client atlas understands: `flip_x` (mirror) and
  # `frames`/`period_ms` (a tile animated across frames packed from `col`).
  @optional_tile_keys ~w(flip_x frames period_ms)

  defp tiles(data) do
    Map.new(data["vocab"], fn {name, v} ->
      base = %{ts: @sheet, col: v["col"], row: v["row"], w: v["w"], h: v["h"]}
      {name, Enum.reduce(@optional_tile_keys, base, &put_optional(&2, &1, v))}
    end)
  end

  defp put_optional(rect, key, v) do
    case v[key] do
      nil -> rect
      value -> Map.put(rect, String.to_atom(key), value)
    end
  end

  defp decor(data) do
    Enum.map(data["decor"], &%{x: &1["x"], y: &1["y"], tile: &1["tile"]})
  end

  defp load do
    :retro_hex_chat
    |> :code.priv_dir()
    |> Path.join("maps/millennial_fair.json")
    |> File.read!()
    |> JSON.decode!()
  end
end
