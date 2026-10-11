defmodule RetroHexChat.VirtualSpace.Maps.Construct do
  @moduledoc """
  The Construct: an empty white floor at the edge of a pale void, with one gate
  back to the End of Time. Everything else in it is placed by the people inside
  (`VirtualSpace.Construct.Layout`).

  Authored by `virtual.space/tools/author_construct.py`, which packs the art
  into `/images/space/construct.webp` and writes `priv/maps/construct.json`.
  Beyond the shared map protocol the JSON carries three things only this scene
  has: the `catalog` of placeable kinds, the `reserved` tiles nobody may build
  on, and `max_items`.
  """

  @sheet "construct"
  @optional_tile_keys [:flip_x, :frames, :period_ms, :wpx, :hpx]

  @spec definition() :: map()
  def definition do
    data = load()

    %{
      id: "construct",
      version: 1,
      width: data["width"],
      height: data["height"],
      tile_size: data["tile_size"],
      projection: data["projection"] || "isometric",
      iso: iso(data["iso"]),
      backdrop: data["backdrop"],
      vignette: vignette(data["vignette"]),
      slabs: [],
      sea: nil,
      railings: [],
      railing_posts: [],
      tilesets: [
        %{
          id: @sheet,
          src: "/images/space/#{@sheet}.webp",
          tile: data["tile_size"],
          columns: data["columns"]
        }
      ],
      tiles: tiles(data["vocab"]),
      ground: data["ground"],
      spawn: Enum.map(data["spawn"], &%{x: &1["x"], y: &1["y"], dir: &1["dir"]}),
      layers: %{floor: data["floor"], decor: decor(data["decor"]), above: []},
      lights: Enum.map(data["lights"] || [], &light/1),
      ambient: nil,
      parallax: [],
      labels: [],
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
      interactables: Enum.map(data["interactables"] || [], &interactable/1),
      seats: [],
      reserved: Enum.map(data["reserved"], fn [x, y] -> %{x: x, y: y} end),
      catalog: catalog(data["catalog"]),
      max_items: data["max_items"]
    }
  end

  defp tiles(vocab) do
    Map.new(vocab, fn {name, v} ->
      base = %{ts: @sheet, col: v["col"], row: v["row"], w: v["w"], h: v["h"]}

      {name,
       Enum.reduce(@optional_tile_keys, base, fn key, rect ->
         case v[Atom.to_string(key)] do
           nil -> rect
           value -> Map.put(rect, key, value)
         end
       end)}
    end)
  end

  defp decor(entries) do
    Enum.map(entries, &%{x: &1["x"], y: &1["y"], tile: &1["tile"], sort: &1["sort"]})
  end

  defp light(l) do
    %{
      x: l["x"],
      y: l["y"],
      radius: l["radius"],
      color: l["color"],
      blend: l["blend"],
      lift: l["lift"]
    }
  end

  defp catalog(entries) do
    Map.new(entries, fn {kind, entry} ->
      {kind,
       %{
         tiles: entry["tiles"],
         seat: entry["seat"] == true,
         lights:
           Enum.map(entry["lights"] || [], fn l ->
             %{radius: l["radius"], color: l["color"], blend: l["blend"], lift: l["lift"]}
           end)
       }}
    end)
  end

  defp interactable(i) do
    %{
      id: i["id"],
      kind: i["kind"],
      x: i["x"],
      y: i["y"],
      title: i["title"],
      modal: %{kind: i["modal"]["kind"], action: i["modal"]["action"]}
    }
  end

  defp iso(%{} = i),
    do: %{tile_w: i["tile_w"], tile_h: i["tile_h"], z_step: i["z_step"], headroom: i["headroom"]}

  defp iso(_), do: nil

  defp vignette(%{} = v), do: %{color: v["color"], alpha: v["alpha"], inner: v["inner"]}
  defp vignette(_), do: nil

  defp load do
    :retro_hex_chat
    |> :code.priv_dir()
    |> Path.join("maps/construct.json")
    |> File.read!()
    |> JSON.decode!()
  end
end
