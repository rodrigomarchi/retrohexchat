defmodule RetroHexChatWeb.Site.About do
  @moduledoc """
  The site's About, a window of the desktop of its own: the project, its
  community, the legal notes and every language the address on screen exists
  in. It stands beside the pages rather than in one — closed until the
  desktop's About icon, the About this site folder or Start ▸ Help opens it.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.I18n.Locales
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Window

  @doc "The About window's declaration."
  @spec window() :: Window.t()
  def window do
    Window.new("about", dgettext("landing", "About"), :icon_lightbulb,
      width: 640,
      body: &about/1,
      status: [dgettext("landing", "MIT License"), dgettext("landing", "v0.1.0")]
    )
  end

  embed_templates "about.html"
end
