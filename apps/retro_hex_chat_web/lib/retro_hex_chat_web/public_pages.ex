defmodule RetroHexChatWeb.PublicPages do
  @moduledoc """
  The public pages, once: the page that opens at each address
  (`Site.Registry`), the desktop's icons, Start ▸ Navigate, the sitemap and
  each page's own address all read this list, so a page added here is a page
  every one of them knows.

  Paths are the canonical, unprefixed ones; a menu localizes them for its
  reader with `localized_path/1`.

  Guides are public pages written for a search rather than for the menus:
  they are in the sitemap and link to each other, but the menus — the same
  on every screen — stay the product's own pages.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Pages

  @typedoc """
  A public page: its name (the route's `live_action`), its address, its icon,
  the label menus link it by and the title its windows go by on the desktop.
  """
  @type page :: %{
          page: atom(),
          path: String.t(),
          label: String.t(),
          title: String.t(),
          icon: atom()
        }

  @pages [
    {:home, "/", :icon_hex_stone, Pages.Index},
    {:features, "/features", :icon_chat, Pages.Features},
    {:games, "/games", :icon_joystick, Pages.Games},
    {:spaces, "/spaces", :icon_group_view, Pages.Spaces},
    {:install, "/install", :icon_terminal, Pages.Install},
    {:community, "/community", :icon_code, Pages.Community},
    {:faq, "/faq", :icon_question, Pages.Faq}
  ]

  @guides [
    {:mirc_commands, "/mirc-commands", :icon_terminal, Pages.MircCommands},
    {:mirc_online, "/mirc-online", :icon_chat, Pages.MircOnline},
    {:irc_chat, "/irc-chat", :icon_channels, Pages.IrcChat},
    {:paint, "/paint", :icon_paint, Pages.Paint},
    {:ascii_art, "/ascii-art", :icon_ascii_art, Pages.AsciiArt},
    {:radio, "/radio", :icon_radio, Pages.Radio}
  ]

  @doc "Every public page, in menu order, labelled in the current locale."
  @spec all() :: [page()]
  def all, do: Enum.map(@pages, &entry/1)

  @doc "Every guide, labelled in the current locale."
  @spec guides() :: [page()]
  def guides, do: Enum.map(@guides, &entry/1)

  @doc "The public page or guide named `page`, or nil."
  @spec find(atom()) :: page() | nil
  def find(page), do: Enum.find(all() ++ guides(), &(&1.page == page))

  @doc "The page module each public page and guide opens, by its name — for `Site.Registry`."
  @spec modules() :: %{atom() => module()}
  def modules,
    do: Map.new(@pages ++ @guides, fn {page, _path, _icon, module} -> {page, module} end)

  @doc "The canonical path of every public page and guide, for the sitemap."
  @spec paths() :: [String.t()]
  def paths, do: Enum.map(@pages ++ @guides, &elem(&1, 1))

  @doc """
  The canonical path of a page by its name. A page that is not one of these —
  a game — names its own path to the layout instead.
  """
  @spec path(atom()) :: String.t()
  def path(page) do
    case List.keyfind(@pages ++ @guides, page, 0) do
      {^page, path, _icon, _module} -> path
      nil -> "/"
    end
  end

  @doc "A help topic's page, in the reader's language: `/pt-BR/chat/help/feature-arcade`."
  @spec help_topic_path(String.t()) :: String.t()
  def help_topic_path(topic_id), do: localized_path("/chat/help/" <> topic_id)

  @doc """
  `path` in the reader's language. Linking the localized address directly spares
  a crawler, and a reader, the redirect an unprefixed one would cost.
  """
  @spec localized_path(String.t()) :: String.t()
  def localized_path(path), do: SEO.localized_path(path, I18n.current_locale())

  defp entry({page, path, icon, _module}) do
    %{page: page, path: path, label: label(page), title: title(page), icon: icon}
  end

  # The home is where the menus go back to, and on the desktop it is what
  # greets a reader.
  defp title(:home), do: dgettext("landing", "Welcome")
  defp title(page), do: label(page)

  defp label(:home), do: dgettext("landing", "Home")
  defp label(:features), do: dgettext("landing", "Features")
  defp label(:games), do: dgettext("landing", "Games")
  defp label(:spaces), do: dgettext("landing", "Spaces")
  defp label(:install), do: dgettext("landing", "Install")
  defp label(:community), do: dgettext("landing", "Community")
  defp label(:faq), do: dgettext("landing", "FAQ")
  defp label(:mirc_commands), do: dgettext("landing", "mIRC commands")
  defp label(:mirc_online), do: dgettext("landing", "mIRC online")
  defp label(:irc_chat), do: dgettext("landing", "IRC chat")
  defp label(:paint), do: "Hex Paint"
  defp label(:ascii_art), do: dgettext("landing", "ASCII Art")
  defp label(:radio), do: "Hex Radio"
end
