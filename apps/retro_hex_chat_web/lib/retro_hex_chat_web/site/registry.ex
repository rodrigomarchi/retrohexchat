defmodule RetroHexChatWeb.Site.Registry do
  @moduledoc """
  Which page of the site a route opens, and which window it opens in.

  The router names a `live_action` for every address of the one desktop. An
  action listed here opens a page — the group of windows of a page of the site,
  or the one window of help, the archive, an invitation or sign-in; any other —
  a channel, a member's home — is the chat's own. The public pages and guides
  come from `RetroHexChatWeb.PublicPages`, the one list the menus, the desktop's
  icons and the sitemap read too; the rest are addresses no menu names.
  """

  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.Pages

  @pages Map.merge(PublicPages.modules(), %{
           game: Pages.Game,
           help_index: Pages.Help,
           help_topic: Pages.Help,
           archive_index: Pages.Archive,
           archive_day: Pages.Archive,
           join: Pages.Join,
           connect: Pages.Connect
         })

  # The one-window slots; a page of the site opens as a group of windows of
  # its own declaring (`Site.Window`), in the `:site` slot.
  @windows %{
    help: "doc-help",
    archive: "doc-archive",
    join: "doc-join",
    connect: "connect"
  }

  @slots [:site | Map.keys(@windows)]

  @doc "The page module a route's action opens, or nil for one of the chat's own addresses."
  @spec page(atom()) :: module() | nil
  def page(action), do: Map.get(@pages, action)

  @doc "The id of the window a one-window slot opens in."
  @spec window_id(atom()) :: String.t()
  def window_id(slot), do: Map.fetch!(@windows, slot)

  @doc "Every one-window slot's window id."
  @spec window_ids() :: [String.t()]
  def window_ids, do: Map.values(@windows)

  @doc "Every page module an address can open."
  @spec pages() :: [module()]
  def pages, do: @pages |> Map.values() |> Enum.uniq()

  @doc """
  The slot a window manager names (`data-document-slot`), or nil for anything
  that is not one — the name arrives from the browser, so it is matched, never
  turned into an atom.
  """
  @spec slot(String.t()) :: atom() | nil
  def slot(name) when is_binary(name), do: Enum.find(@slots, &(Atom.to_string(&1) == name))
  def slot(_name), do: nil
end
