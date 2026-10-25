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
         Window.intro(dgettext("landing", "Open Source and Community"), :icon_code,
           taskbar_label: dgettext("landing", "Community"),
           heading_id: "community-heading",
           description:
             dgettext(
               "landing",
               "Retro Hex Chat is MIT-licensed open source software. Follow the repository, contribute code or translations, report issues, or sponsor continued development."
             ),
           status: [dgettext("landing", "Community overview")]
         ),
         Window.new("open-source", dgettext("landing", "Open Source"), :icon_code,
           width: 560,
           body: &open_source/1,
           status: [dgettext("landing", "MIT License"), dgettext("landing", "Contribute!")]
         ),
         Window.new(
           "support-the-project",
           dgettext("landing", "Support the Project"),
           :icon_heart,
           width: 680,
           body: &support_the_project/1,
           status: [dgettext("landing", "Thank you!")]
         ),
         Window.new("tech-stack", dgettext("landing", "Tech Stack"), :icon_server,
           width: 560,
           body: &tech_stack/1,
           assigns: %{
             stack: [
               {:icon_elixir, dgettext("landing", "Backend"),
                dgettext("landing", "Elixir, Phoenix, LiveView")},
               {:icon_postgres, dgettext("landing", "Database"),
                dgettext("landing", "PostgreSQL")},
               {:icon_palette, dgettext("landing", "Frontend"),
                dgettext("landing", "Retro CSS, Vanilla JS, Canvas")},
               {:icon_websocket, dgettext("landing", "Real-time"),
                dgettext("landing", "Phoenix Channels, PubSub")},
               {:icon_group_view, dgettext("landing", "Spaces"),
                dgettext("landing", "Canvas map runtime")},
               {:icon_webrtc, dgettext("landing", "Private P2P"),
                dgettext("landing", "WebRTC sessions")},
               {:icon_conference, dgettext("landing", "Conferences"),
                dgettext("landing", "Self-hosted WebRTC SFU")}
             ]
           },
           status: [{:check, dgettext("landing", "Open source stack")}]
         )
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

  embed_templates "community/*"
end
