defmodule RetroHexChatWeb.Site.Pages.Community do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    {:ok,
     %{
       active_page: :community,
       windows: [
         %{id: "intro", label: dgettext("landing", "Community"), icon: :icon_community},
         %{id: "open-source", label: dgettext("landing", "Open Source"), icon: :icon_code},
         %{
           id: "support-the-project",
           label: dgettext("landing", "Support the Project"),
           icon: :icon_star
         },
         %{id: "tech-stack", label: dgettext("landing", "Tech Stack"), icon: :icon_server}
       ],
       canonical_path: "/community",
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), "/"},
           {dgettext("landing", "Community"), "/community"}
         ])
       ],
       page_title: dgettext("landing", "Open Source & Community — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Retro Hex Chat is MIT-licensed open source software. Contribute, star, share, or sponsor the project on GitHub."
         )
     }}
  end

  embed_templates "community.html"

  @impl RetroHexChatWeb.Site.Page
  def render(assigns), do: community(assigns)
end
