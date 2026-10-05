defmodule RetroHexChatWeb.PublicPages do
  @moduledoc """
  The public pages, once: the landing's Start menu, menu bar and taskbar, the
  chat's Start menu, the sitemap and each page's own address all read this
  list, so a page added here is a page every one of them knows.

  Paths are the canonical, unprefixed ones; a menu localizes them for its
  reader with `localized_path/1`.

  Guides are public pages written for a search rather than for the menus:
  they are in the sitemap and link to each other, but the menus — the same
  on every screen — stay the product's own pages.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.SEO

  @type page :: %{page: atom(), path: String.t(), label: String.t(), icon: atom()}

  @pages [
    {:home, "/", :icon_hex_stone},
    {:how_it_works, "/how-it-works", :icon_server},
    {:features, "/features", :icon_chat},
    {:games, "/games", :icon_joystick},
    {:privacy, "/privacy", :icon_lock},
    {:install, "/install", :icon_terminal},
    {:community, "/community", :icon_code},
    {:faq, "/faq", :icon_question}
  ]

  @guides [
    {:mirc_commands, "/mirc-commands", :icon_terminal},
    {:mirc_online, "/mirc-online", :icon_chat},
    {:irc_chat, "/irc-chat", :icon_channels}
  ]

  @doc "Every public page, in menu order, labelled in the current locale."
  @spec all() :: [page()]
  def all do
    Enum.map(@pages, fn {page, path, icon} ->
      %{page: page, path: path, label: label(page), icon: icon}
    end)
  end

  @doc "Every guide, labelled in the current locale."
  @spec guides() :: [page()]
  def guides do
    Enum.map(@guides, fn {page, path, icon} ->
      %{page: page, path: path, label: label(page), icon: icon}
    end)
  end

  @doc "The canonical path of every public page and guide, for the sitemap."
  @spec paths() :: [String.t()]
  def paths, do: Enum.map(@pages ++ @guides, &elem(&1, 1))

  @doc """
  The canonical path of a page by its name. A page that is not one of these —
  an archive day, a game — names its own path to the layout instead.
  """
  @spec path(atom()) :: String.t()
  def path(page) do
    case List.keyfind(@pages ++ @guides, page, 0) do
      {^page, path, _icon} -> path
      nil -> "/"
    end
  end

  @doc """
  `path` in the reader's language. Linking the localized address directly spares
  a crawler, and a reader, the redirect an unprefixed one would cost.
  """
  @spec localized_path(String.t()) :: String.t()
  def localized_path(path), do: SEO.localized_path(path, I18n.current_locale())

  defp label(:home), do: dgettext("landing", "Home")
  defp label(:how_it_works), do: dgettext("landing", "How It Works")
  defp label(:features), do: dgettext("landing", "Features")
  defp label(:games), do: dgettext("landing", "Games")
  defp label(:privacy), do: dgettext("landing", "Privacy")
  defp label(:install), do: dgettext("landing", "Install")
  defp label(:community), do: dgettext("landing", "Community")
  defp label(:faq), do: dgettext("landing", "FAQ")
  defp label(:mirc_commands), do: dgettext("landing", "mIRC commands")
  defp label(:mirc_online), do: dgettext("landing", "mIRC online")
  defp label(:irc_chat), do: dgettext("landing", "IRC chat")
end
