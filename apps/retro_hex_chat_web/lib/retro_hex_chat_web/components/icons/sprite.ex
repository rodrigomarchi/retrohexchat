defmodule RetroHexChatWeb.Icons.Sprite do
  @moduledoc """
  Where an icon's drawing lives once the page stops carrying it.

  Every icon component renders `<use href={href(:icon_name)} />`. The drawing
  itself sits in one sprite document, written at build time by
  `mix retrohex.icons.sprite` and fingerprinted by `phx.digest`, so the browser
  fetches it once and reuses it for every icon on every page of the session.

  `/connect` used to inline 169 drawings of which only 94 were distinct.
  """

  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.Icons.Registry

  @path "/assets/icons/sprite.svg"

  @doc """
  The un-digested path the sprite is served from.
  """
  @spec path() :: String.t()
  def path, do: @path

  @doc """
  The digested sprite URL, so it can be preloaded alongside the stylesheet.
  """
  @spec url() :: String.t()
  def url, do: Endpoint.static_path(@path)

  @doc """
  The URL a `<use>` needs to resolve one icon out of the sprite.
  """
  @spec href(atom()) :: String.t()
  def href(name) when is_atom(name), do: url() <> "#" <> Registry.sprite_id(name)
end
