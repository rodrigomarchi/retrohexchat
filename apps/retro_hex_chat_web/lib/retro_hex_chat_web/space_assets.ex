defmodule RetroHexChatWeb.SpaceAssets do
  @moduledoc """
  Digested URLs for the sprite sheets the virtual space draws from.

  The client slices its world out of a handful of sheets: one per character
  class, one for the combat effects, and one per map. They are the heaviest
  thing the app serves, and they change only when the art does — so they want
  the year-long `immutable` cache that `Plug.Static` grants a request carrying
  the digest's `?vsn=`. A URL spelled in the JS bundle cannot carry that, because
  the hash changes with the next build and the bundle is cached too. So the
  server spells them, and the client is handed the list.

  The map's own tileset is named by the domain, which knows nothing about routes
  or digests — `digest_map/1` is where that logical path becomes a real URL, on
  the way out through the channel.

  WebP, and only WebP, for the reason `RetroHexChatWeb.Wallpaper` gives: the art
  is high-colour and PNG cannot compress it. Unlike the wallpaper there is no
  colour underneath to fall back to, so a browser that cannot decode WebP draws
  no world at all — which is every browser shipped since 2020 having to be wrong.
  """

  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.Endpoint

  @fx_sheet_id "fx_combat"
  @fx_path "/images/space/fx.webp"

  @doc """
  Sheet id to digested URL, for every sheet the atlas can be asked to load.

  Keys match the atlas's own sheet ids (`av_iso_<class>`, `fx_combat`), so the
  client looks a sheet up by the name it already uses.
  """
  @spec sheet_urls() :: %{String.t() => String.t()}
  def sheet_urls do
    avatars =
      Map.new(VirtualSpace.avatars(), fn id ->
        {"av_iso_#{id}", Endpoint.static_path("/images/space/avatars/iso_#{id}.webp")}
      end)

    Map.put(avatars, @fx_sheet_id, Endpoint.static_path(@fx_path))
  end

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
