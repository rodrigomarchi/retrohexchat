defmodule RetroHexChat.VirtualSpace.Maps.Catalog do
  @moduledoc """
  The full tile catalog: every usable, well-drawn tile across the human-made
  sheets (`overworld`, `inner`, `cave`, `objects`, `character`, `log`), named and
  ready to drop into a map.

  Each entry resolves a semantic name to a source rectangle on a sheet
  (`%{ts, col, row, w, h}`), the same shape a map's `tiles` map uses. Build a map
  by picking names — `Catalog.tiles(~w(grass_plain tree_foliage house_large))` —
  and ship `Catalog.tilesets()` so the client loads every sheet.

  The catalog data lives in `priv/maps/tile_catalog.json` and is baked in at
  compile time; the browsable table (name, art description, layer, collision)
  is `docs/reference/space-tiles.md`. Each entry carries `layer`
  ("floor"/"decor"/"above") and `solid` (blocks movement) so a map author — human
  or AI — can place it correctly without seeing the art.
  """

  @external_resource Path.expand("../../../../priv/maps/tile_catalog.json", __DIR__)

  @entries @external_resource |> File.read!() |> JSON.decode!()

  @sheets ~w(overworld inner cave objects character log)

  @columns %{
    "overworld" => 40,
    "inner" => 40,
    "cave" => 40,
    "objects" => 33,
    "character" => 17,
    "log" => 12
  }

  @by_name Elixir.Map.new(@entries, fn e ->
             {e["name"],
              %{
                ts: e["sheet"],
                col: e["col"],
                row: e["row"],
                w: Elixir.Map.get(e, "w", 1),
                h: Elixir.Map.get(e, "h", 1)
              }}
           end)

  @info Elixir.Map.new(@entries, fn e ->
          {e["name"],
           %{
             name: e["name"],
             sheet: e["sheet"],
             col: e["col"],
             row: e["row"],
             w: Elixir.Map.get(e, "w", 1),
             h: Elixir.Map.get(e, "h", 1),
             category: e["category"],
             layer: e["layer"],
             solid: e["solid"],
             desc: e["desc"],
             review: Elixir.Map.get(e, "review", false)
           }}
        end)

  @doc "Every catalog entry, as raw maps (name/sheet/col/row/w/h/category/layer/solid/desc)."
  @spec all() :: [map()]
  def all, do: @entries

  @doc "Names of every catalogued tile."
  @spec names() :: [String.t()]
  def names, do: Elixir.Map.keys(@by_name)

  @doc "Resolve one tile name to its source rect, or nil."
  @spec tile(String.t()) ::
          %{ts: String.t(), col: integer(), row: integer(), w: integer(), h: integer()} | nil
  def tile(name), do: Elixir.Map.get(@by_name, name)

  @doc """
  Full metadata for one tile: source rect plus `category`, `layer`
  ("floor"/"decor"/"above"), `solid` (blocks movement), `desc` and `review`
  (true when the crop is imperfect and should be double-checked). Nil if unknown.
  """
  @spec info(String.t()) :: map() | nil
  def info(name), do: Elixir.Map.get(@info, name)

  @doc "Whether a tile blocks movement (used to seed collision from decor)."
  @spec solid?(String.t()) :: boolean()
  def solid?(name) do
    case Elixir.Map.get(@info, name) do
      %{solid: solid} -> solid
      nil -> false
    end
  end

  @doc """
  Resolve a list of names into a `name => source-rect` map, the shape a map
  definition's `tiles` field expects. Unknown names are dropped.
  """
  @spec tiles([String.t()]) :: %{optional(String.t()) => map()}
  def tiles(names) do
    for name <- names, rect = Elixir.Map.get(@by_name, name), into: %{}, do: {name, rect}
  end

  @doc "Tileset descriptors for every sheet, for the client to load."
  @spec tilesets() :: [map()]
  def tilesets do
    for id <- @sheets do
      %{id: id, src: "/images/space/#{id}.png", tile: 16, columns: @columns[id]}
    end
  end
end
