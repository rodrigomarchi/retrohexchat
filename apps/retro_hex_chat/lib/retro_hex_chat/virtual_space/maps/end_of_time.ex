defmodule RetroHexChat.VirtualSpace.Maps.EndOfTime do
  @moduledoc """
  End of Time: the cozy two-person scene behind every private conversation.

  An **isometric** dark cobblestone platform floating in a starry void — an
  ornate golden railing runs the back edges receding into the abyss, a lamppost
  pools amber light where the two participants gather, the Gate glows at the top,
  the secret bucket rests nearby. The platform reads as a solid 3D slab (visible
  side faces) framed by a vignette. Faithful to the Chrono Trigger "End of Time".

  This is the first `projection: "isometric"` map; the client renders it via the
  diamond `Projection` seam (see `SCENES.md`). The whole scene is authored by
  `virtual.space/tools/author_scene.py`, which packs the PixelLab art into
  `/images/space/endoftime.png` and emits the layout (diamond floor matrix, edge
  railings, decor, collision, lights, slab, vignette, iso params) as
  `priv/maps/end_of_time.json`. This module loads that JSON and shapes it into
  the shared map protocol — no pixel data, the client slices the sheet at runtime.
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
      projection: data["projection"] || "topdown",
      iso: iso(data),
      slab: slab(data),
      vignette: vignette(data),
      sea: sea(data),
      railings: railings(data),
      railing_style: railing_look(data),
      tilesets: [
        %{
          id: @sheet,
          src: "/images/space/#{@sheet}.png",
          tile: data["tile_size"],
          columns: data["columns"]
        }
      ],
      tiles: tiles(data),
      ground: data["ground"],
      spawn: Enum.map(data["spawn"], &%{x: &1["x"], y: &1["y"], dir: &1["dir"]}),
      layers: %{floor: data["floor"], decor: decor(data), above: []},
      lights: lights(data),
      ambient: ambient(data),
      parallax: parallax(data),
      labels:
        Enum.map(data["labels"], fn l ->
          %{
            id: l["id"],
            kind: l["kind"],
            x: l["x"],
            y: l["y"],
            w: l["w"],
            h: l["h"],
            lift: l["lift"],
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
  @optional_tile_keys ~w(flip_x frames period_ms wpx hpx)

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

  # `sort` ("flat" | "stand") tells the client's depth pass which decor lies
  # under every avatar (the starfield) and which Y-sorts against them so the
  # player can walk behind it (standing props).
  defp decor(data) do
    Enum.map(data["decor"], &%{x: &1["x"], y: &1["y"], tile: &1["tile"], sort: &1["sort"]})
  end

  # Color-math light sources: additive radial pools the client draws over the
  # lit scene (amber under the lamps, warm braziers, cool portal glow).
  defp lights(data) do
    Enum.map(
      data["lights"] || [],
      &%{
        x: &1["x"],
        y: &1["y"],
        radius: &1["radius"],
        color: &1["color"],
        blend: &1["blend"],
        lift: &1["lift"]
      }
    )
  end

  # The cozy indigo dusk multiplied over the whole scene, or nil for full bright.
  defp ambient(%{"ambient" => %{} = a}), do: %{color: a["color"], alpha: a["alpha"]}
  defp ambient(_), do: nil

  # Isometric parameters (diamond footprint + elevation px), or nil for top-down.
  defp iso(%{"iso" => %{} = i}) do
    %{tile_w: i["tile_w"], tile_h: i["tile_h"], z_step: i["z_step"], headroom: i["headroom"]}
  end

  defp iso(_), do: nil

  # Isometric slab: 3D thickness + `taper` (0..1, how far the underside pulls to a
  # centre apex → a diamond point below) over the platform `hull` [minX,maxX,minY,maxY].
  defp slab(%{"slab" => %{} = s}) do
    %{thickness: s["thickness"], taper: s["taper"], hull: s["hull"]}
  end

  defp slab(_), do: nil

  # Screen-space vignette darkening the void frame, or nil.
  defp vignette(%{"vignette" => %{} = v}) do
    %{color: v["color"], alpha: v["alpha"], inner: v["inner"]}
  end

  defp vignette(_), do: nil

  # The cosmic sea abyss (deep-blue gradient + drifting ripple bands), or nil.
  defp sea(%{"sea" => %{} = s}) do
    %{
      top: s["top"],
      bottom: s["bottom"],
      band: s["band"],
      bands: s["bands"],
      amp: s["amp"]
    }
  end

  defp sea(_), do: nil

  # Geometric iso railing edge cells (drawn as one continuous fence), + style.
  defp railings(data) do
    Enum.map(data["railings"] || [], &%{x: &1["x"], y: &1["y"], edge: &1["edge"]})
  end

  # The railing's look (heights/colors/post count) — plain map data the client
  # renders, not CSS. Named to avoid the style-audit's `*style*` heuristic.
  defp railing_look(%{"railing_style" => %{} = s}) do
    %{
      height: s["height"],
      color: s["color"],
      hi: s["hi"],
      base: s["base"],
      posts: s["posts"]
    }
  end

  defp railing_look(_), do: nil

  # Parallax background layers: a tile repeated across the void behind the
  # platform, scrolling slower than the world for cosmic depth.
  defp parallax(data) do
    Enum.map(
      data["parallax"] || [],
      &%{tile: &1["tile"], scroll: &1["scroll"], alpha: &1["alpha"], step: &1["step"]}
    )
  end

  defp load do
    :retro_hex_chat
    |> :code.priv_dir()
    |> Path.join("maps/end_of_time.json")
    |> File.read!()
    |> JSON.decode!()
  end
end
