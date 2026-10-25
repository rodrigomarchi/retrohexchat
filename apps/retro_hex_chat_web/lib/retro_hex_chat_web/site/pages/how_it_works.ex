defmodule RetroHexChatWeb.Site.Pages.HowItWorks do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    {:ok,
     %{
       active_page: :how_it_works,
       windows: [
         Window.intro(dgettext("landing", "How Retro Hex Chat Works"), :icon_server,
           taskbar_label: dgettext("landing", "How It Works"),
           heading_id: "how-it-works-heading",
           description:
             dgettext(
               "landing",
               "Retro Hex Chat combines a self-hosted Phoenix server with real-time chat, channel Spaces, private WebRTC peer-to-peer sessions, and self-hosted channel conferences."
             ),
           status: [dgettext("landing", "Architecture overview")]
         ),
         Window.new("your-server", dgettext("landing", "Your Server"), :icon_server,
           width: 620,
           body: &your_server/1,
           status: [{:check, dgettext("landing", "Self-hosted")}]
         ),
         Window.new(
           "private-p2p-connections",
           dgettext("landing", "Private P2P Connections"),
           :icon_p2p,
           width: 520,
           body: &private_p2p_connections/1,
           status: [{:check, dgettext("landing", "Peer-to-peer")}]
         ),
         Window.new("virtual-spaces", dgettext("landing", "Virtual Spaces"), :icon_group_view,
           width: 620,
           body: &virtual_spaces/1,
           status: [{:check, dgettext("landing", "Space runtime")}]
         ),
         Window.new(
           "channel-conferences",
           dgettext("landing", "Channel Conferences"),
           :icon_conference,
           width: 620,
           body: &channel_conferences/1,
           status: [{:check, dgettext("landing", "SFU routed")}]
         ),
         Window.new("privacy-comparison", dgettext("landing", "Privacy Comparison"), :icon_shield,
           width: 780,
           body: &privacy_comparison/1,
           assigns: %{
             theirs: dgettext("landing", "Big Tech"),
             rows: [
               {dgettext("landing", "Messages"),
                dgettext("landing", "Stored on their servers, mined for ads"),
                dgettext("landing", "Stored on YOUR server, never leaves")},
               {dgettext("landing", "Calls"),
                dgettext("landing", "Routed through corporate infrastructure"),
                dgettext("landing", "Private P2P, or conferences routed by your own server")},
               {dgettext("landing", "Your data"),
                dgettext("landing", "Trains their AI, sold to advertisers"),
                dgettext("landing", "Stays in your database, period")},
               {dgettext("landing", "Code"), dgettext("landing", "Closed source — trust us"),
                dgettext("landing", "Open source — verify yourself")},
               {dgettext("landing", "Control"), dgettext("landing", "They can ban you anytime"),
                dgettext("landing", "You own the server — nobody can")}
             ]
           },
           status: [{:check, dgettext("landing", "Your data")}]
         ),
         Window.new("install-app", dgettext("landing", "Keep It On Your Device"), :icon_hex_stone,
           width: 420,
           body: &install_app/1,
           status: [{:check, dgettext("landing", "No store required")}]
         ),
         Window.new("security-layers", dgettext("landing", "Security Layers"), :icon_security,
           width: 420,
           body: &security_layers/1,
           status: [{:check, dgettext("landing", "Encrypted")}]
         )
       ],
       canonical_path: "/how-it-works",
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), "/"},
           {dgettext("landing", "How It Works"), "/how-it-works"}
         ])
       ],
       page_title:
         dgettext("landing", "How Retro Hex Chat Works — Server, Spaces, Calls & Privacy"),
       page_description:
         dgettext(
           "landing",
           "Learn how Retro Hex Chat works: self-hosted chat, virtual Spaces, private WebRTC P2P sessions, channel conferences, privacy, and security."
         )
     }}
  end

  embed_templates "how_it_works/*"
end
