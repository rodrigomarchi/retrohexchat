defmodule RetroHexChatWeb.Site.Registry do
  @moduledoc """
  Which page of the site a route opens, and which window it opens in.

  The router names a `live_action` for every address of the one desktop. An
  action listed here opens a page's document window; any other — a channel, a
  member's home — is the chat's own. The menus and the sitemap still read the
  page list from `RetroHexChatWeb.PublicPages`.
  """

  alias RetroHexChatWeb.Site.Pages

  @pages %{
    home: Pages.Index,
    how_it_works: Pages.HowItWorks,
    features: Pages.Features,
    privacy: Pages.Privacy,
    install: Pages.Install,
    community: Pages.Community,
    faq: Pages.Faq,
    games: Pages.Games,
    game: Pages.Game,
    mirc_commands: Pages.MircCommands,
    mirc_online: Pages.MircOnline,
    irc_chat: Pages.IrcChat,
    help_index: Pages.Help,
    help_topic: Pages.Help,
    archive_index: Pages.Archive,
    archive_day: Pages.Archive,
    join: Pages.Join,
    connect: Pages.Connect
  }

  @windows %{
    site: "doc-site",
    help: "doc-help",
    archive: "doc-archive",
    join: "doc-join",
    connect: "connect"
  }

  @doc "The page module a route's action opens, or nil for one of the chat's own addresses."
  @spec page(atom()) :: module() | nil
  def page(action), do: Map.get(@pages, action)

  @doc "The id of the document window a slot opens in."
  @spec window_id(atom()) :: String.t()
  def window_id(slot), do: Map.fetch!(@windows, slot)

  @doc "The slot a document window id belongs to, or nil for any other window."
  @spec slot_of(String.t()) :: atom() | nil
  def slot_of(window_id) do
    Enum.find_value(@windows, fn {slot, id} -> id == window_id && slot end)
  end

  @doc "Every document window id."
  @spec window_ids() :: [String.t()]
  def window_ids, do: Map.values(@windows)
end
