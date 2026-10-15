defmodule RetroHexChat.VirtualSpace.Maps.Construct do
  @moduledoc """
  The Construct: an empty white floor floating in the End of Time's own sky —
  its sea, its stars, a slab under the island — with one gate back.
  Everything else in it is placed by the people inside
  (`VirtualSpace.Construct.Layout`).

  Authored by `virtual.space/tools/author_construct.py`, which packs the art
  into `/images/space/construct.webp` and writes `priv/maps/construct.json`.
  Beyond the shared map protocol a buildable room's JSON carries the `catalog`
  of placeable kinds, the `reserved` tiles nobody may build on, `max_items`,
  the floor `materials` it can be painted with (each a one-character floor
  tile), and `fixed_items`: the furniture it comes with, each an `id`
  (`fixed:<n>`), `kind`, `x`, `y` and `dir`, placed like anybody's piece. The
  Office (`Maps.Office`) is read through this module from its own file, with
  the same catalog and sheets.

  A catalog entry names the kind's tile per facing, and optionally: `seat`,
  `lights`, `blocks` (false for a piece you walk onto), `dirs` (the facings it
  turns through), `use` (what E does to it), `states` (its other sprites, per
  state, per facing), `only` (the conversations it may be built in) and
  `group` (its palette tab), `label` (how the line it shows is drawn: its
  width in tiles, how high it floats, its colour and its outline), `size`
  (its footprint, `[w, h]` tiles), `foot` (the point of the footprint its art
  stands on), `seats` (the footprint tiles that are seats) and `layers` (more
  art drawn with it, each on its own point).
  """

  @sheet "construct"
  @optional_tile_keys [:flip_x, :frames, :period_ms, :wpx, :hpx]

  @spec definition() :: map()
  def definition, do: definition("construct")

  @doc "A buildable room authored as `priv/maps/<id>.json`."
  @spec definition(String.t()) :: map()
  def definition(id) do
    data = load(id)

    %{
      id: id,
      version: 1,
      width: data["width"],
      height: data["height"],
      tile_size: data["tile_size"],
      projection: data["projection"] || "isometric",
      iso: iso(data["iso"]),
      backdrop: data["backdrop"],
      vignette: vignette(data["vignette"]),
      slabs:
        Enum.map(
          data["slabs"] || [],
          &%{thickness: &1["thickness"], taper: &1["taper"], hull: &1["hull"]}
        ),
      sea: sea(data["sea"]),
      railings: [],
      railing_posts: [],
      tilesets: tilesets(data),
      tiles: tiles(data["vocab"]),
      ground: data["ground"],
      spawn: Enum.map(data["spawn"], &%{x: &1["x"], y: &1["y"], dir: &1["dir"]}),
      layers: %{floor: data["floor"], decor: decor(data["decor"]), above: []},
      lights: Enum.map(data["lights"] || [], &light/1),
      ambient: nil,
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
      fixed_items: Enum.map(data["fixed_items"] || [], &fixed_item/1),
      reserved: Enum.map(data["reserved"], fn [x, y] -> %{x: x, y: y} end),
      catalog: catalog(data["catalog"]),
      materials: Enum.map(data["materials"] || [], &%{id: &1["id"], tile: &1["tile"]}),
      max_items: data["max_items"]
    }
  end

  # The Construct's own sheet, and the End of Time's, whose pieces it places
  # with the End of Time's own art.
  defp tilesets(data) do
    sheets = data["tilesets"] || [%{"id" => @sheet, "columns" => data["columns"]}]

    Enum.map(sheets, fn sheet ->
      %{
        id: sheet["id"],
        src: "/images/space/#{sheet["id"]}.webp",
        tile: data["tile_size"],
        columns: sheet["columns"]
      }
    end)
  end

  defp tiles(vocab) do
    Map.new(vocab, fn {name, v} ->
      base = %{ts: v["ts"] || @sheet, col: v["col"], row: v["row"], w: v["w"], h: v["h"]}

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
           end),
         blocks: entry["blocks"] != false,
         dirs: entry["dirs"] || ["down", "right"],
         use: entry["use"],
         states: entry["states"] || %{},
         only: entry["only"],
         group: entry["group"] || "furniture",
         label: label(entry["label"]),
         size: entry["size"] || [1, 1],
         foot: entry["foot"],
         seats: entry["seats"],
         layers: Enum.map(entry["layers"] || [], &%{tiles: &1["tiles"], foot: &1["foot"]})
       }}
    end)
  end

  defp label(%{} = l), do: %{w: l["w"], lift: l["lift"], color: l["color"], glow: l["glow"]}
  defp label(_none), do: nil

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

  defp fixed_item(i),
    do: %{id: i["id"], kind: i["kind"], x: i["x"], y: i["y"], dir: i["dir"] || "down"}

  defp iso(%{} = i),
    do: %{tile_w: i["tile_w"], tile_h: i["tile_h"], z_step: i["z_step"], headroom: i["headroom"]}

  defp iso(_), do: nil

  defp sea(%{} = s),
    do: %{top: s["top"], bottom: s["bottom"], band: s["band"], bands: s["bands"], amp: s["amp"]}

  defp sea(_), do: nil

  defp vignette(%{} = v), do: %{color: v["color"], alpha: v["alpha"], inner: v["inner"]}
  defp vignette(_), do: nil

  defp load(id) do
    :retro_hex_chat
    |> :code.priv_dir()
    |> Path.join("maps/#{id}.json")
    |> File.read!()
    |> JSON.decode!()
  end
end
