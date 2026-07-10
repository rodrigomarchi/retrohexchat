defmodule RetroHexChat.VirtualSpace.Maps.EndOfTime do
  @moduledoc """
  End of Time: the cozy two-person scene behind every private conversation.

  A warm, weathered stone island adrift in a starry cosmic void — a lamppost
  pooling amber light at the centre where the two participants gather, framed by
  mossy pillars, a bench, a bucket, a potted sapling and an era signpost. The
  vibe borrows the Chrono Trigger "End of Time" rest stop.

  The whole scene is authored by `virtual.space/tools/author_scene.py`, which
  packs the PixelLab art into `/images/space/endoftime.png` and emits the layout
  (autotiled floor matrix, decor, collision, spawns, and the tile `vocab`) as
  `priv/maps/end_of_time.json`. This module loads that JSON and shapes it into
  the shared map protocol — no pixel data, the client slices the sheet at
  runtime. See `virtual.space/SCENES.md`.
  """

  @sheet "endoftime"

  @spec definition() :: map()
  def definition do
    data = load()

    %{
      id: "end_of_time",
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
      zones:
        Enum.map(
          data["zones"],
          &%{id: &1["id"], kind: &1["kind"], x: &1["x"], y: &1["y"], w: &1["w"], h: &1["h"]}
        ),
      interactables: [],
      seats: []
    }
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
    |> Path.join("maps/end_of_time.json")
    |> File.read!()
    |> JSON.decode!()
  end
end
