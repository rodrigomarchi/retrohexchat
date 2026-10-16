defmodule RetroHexChatWeb.Site.Pages.Privacy do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    {:ok,
     %{
       active_page: :privacy,
       windows: [
         %{id: "intro", label: dgettext("landing", "Privacy"), icon: :icon_lock},
         %{
           id: "big-tech-platforms",
           label: dgettext("landing", "Big Tech Platforms"),
           icon: :icon_warning
         },
         %{
           id: "retro-hex-chat",
           label: dgettext("landing", "Retro Hex Chat"),
           icon: :icon_hex_stone
         },
         %{
           id: "side-by-side-comparison",
           label: dgettext("landing", "Side-by-side comparison"),
           icon: :icon_group_view
         }
       ],
       canonical_path: "/privacy",
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), "/"},
           {dgettext("landing", "Privacy"), "/privacy"}
         ])
       ],
       page_title:
         dgettext("landing", "Privacy Comparison — Retro Hex Chat vs Discord, Slack & Telegram"),
       page_description:
         dgettext(
           "landing",
           "Side-by-side privacy comparison: data ownership, call routing, message access, AI training, and source code transparency."
         )
     }}
  end

  embed_templates "privacy.html"

  @impl RetroHexChatWeb.Site.Page
  def render(assigns), do: privacy(assigns)
end
