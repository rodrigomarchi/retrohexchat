defmodule RetroHexChatWeb.SpaceAssets do
  @moduledoc """
  Digested URLs for the sprite sheets the virtual space draws from.

  The client slices its world out of a handful of sheets: the combat effects,
  the canvas UI kit, one per map, and the character creator's pieces (listed in
  its catalog, `character_catalog_url/0`). They are the heaviest thing the app
  serves, and they change only when the art does — so they want
  the year-long `immutable` cache that `Plug.Static` grants a request carrying
  the digest's `?vsn=`. A URL spelled in the JS bundle cannot carry that, because
  the hash changes with the next build and the bundle is cached too. So the
  server spells them, and the client is handed the list.

  The map's own tileset is named by the domain, which knows nothing about routes
  or digests — `digest_map/1` is where that logical path becomes a real URL, on
  the way out through the channel.

  The world's sheets are WebP, for the reason `RetroHexChatWeb.Wallpaper` gives:
  the art is high-colour and PNG cannot compress it. The character pieces are
  the exception, and on purpose: each holds at most 256 colours, and their
  recolouring is a rewrite of an indexed PNG's palette, which WebP does not
  have. The catalog carries each piece's URL with its own `?vsn=`, so they are
  cached as long as the rest.
  """

  alias RetroHexChatWeb.Endpoint

  @fx_sheet_id "fx_combat"
  @fx_path "/images/space/fx.webp"
  # The pixel-art frames the canvas draws its own UI with (bubbles, nameplates,
  # signs, the HP bar), packed by virtual.space/tools/author_ui.py.
  @ui_sheet_id "ui_canvas"
  @ui_path "/images/space/ui/canvas.webp"
  # The character creator's catalog, written by virtual.space/tools/build_creator.py.
  @character_catalog_path "/images/space/creator/catalog.json"

  @doc """
  Sheet id to digested URL, for every sheet the atlas can be asked to load.

  Keys match the atlas's own sheet ids (`fx_combat`, `ui_canvas`), so the
  client looks a sheet up by the name it already uses.
  """
  @spec sheet_urls() :: %{String.t() => String.t()}
  def sheet_urls do
    %{
      @fx_sheet_id => Endpoint.static_path(@fx_path),
      @ui_sheet_id => Endpoint.static_path(@ui_path)
    }
  end

  @doc "The digested URL of the character creator's catalog."
  @spec character_catalog_url() :: String.t()
  def character_catalog_url, do: Endpoint.static_path(@character_catalog_path)

  @doc """
  `sheet_urls/0` as JSON, for a `data-` attribute on the space canvas element.
  """
  @spec sheet_urls_json() :: String.t()
  def sheet_urls_json, do: Jason.encode!(sheet_urls())

  @doc """
  Rewrite a map definition's tileset sources as digested URLs.

  Every other field is passed through untouched — this only translates the
  logical path the domain emits into the one the browser should ask for.
  """
  @spec digest_map(map()) :: map()
  def digest_map(%{tilesets: tilesets} = map) when is_list(tilesets) do
    %{map | tilesets: Enum.map(tilesets, &digest_tileset/1)}
  end

  def digest_map(map), do: map

  @spec digest_tileset(map()) :: map()
  defp digest_tileset(%{src: src} = tileset) when is_binary(src) do
    %{tileset | src: Endpoint.static_path(src)}
  end

  defp digest_tileset(tileset), do: tileset
end
