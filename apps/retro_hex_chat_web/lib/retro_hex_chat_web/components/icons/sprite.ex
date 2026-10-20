defmodule RetroHexChatWeb.Icons.Sprite do
  @moduledoc """
  Where an icon's drawing lives once the page stops carrying it.

  Every icon component renders `<use href={href(:icon_name)} />`. The drawing
  itself sits in one sprite document, written at build time by
  `mix retrohex.icons.sprite` and fingerprinted by `phx.digest`, so the browser
  fetches it once and reuses it for every icon on every page of the session.

  `/connect` used to inline 169 drawings of which only 94 were distinct.
  """

  alias Phoenix.HTML.Safe
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

  @doc """
  One icon as a document of its own, `size` pixels square, for a surface that
  cannot point into the sprite — a canvas draws an image, not a `<use>`.
  """
  @spec standalone(atom(), pos_integer()) :: String.t()
  def standalone(name, size) when is_atom(name) and is_integer(size) and size > 0 do
    module = Enum.find_value(Registry.all(), fn {icon, module} -> icon == name && module end)

    svg =
      module
      |> apply(name, [%{class: nil, __changed__: nil}])
      |> Safe.to_iodata()
      |> IO.iodata_to_binary()
      |> String.replace(~r/<!--.*?-->/s, "")
      |> String.replace(~r/\s(?:class|aria-hidden|data-phx-[a-z-]+)="[^"]*"/, "")
      |> String.trim()

    String.replace(
      svg,
      "<svg",
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}"),
      global: false
    )
  end
end
