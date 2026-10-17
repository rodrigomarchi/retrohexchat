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
         Window.new("intro", dgettext("landing", "Privacy Comparison"), :icon_lock,
           width: 640,
           taskbar_label: dgettext("landing", "Privacy"),
           body: &page_intro/1,
           assigns: %{
             heading_id: "privacy-heading",
             description:
               dgettext(
                 "landing",
                 "Compare Retro Hex Chat with corporate chat platforms across server ownership, message storage, call routing, AI training, source code access, and community control."
               )
           },
           status: [dgettext("landing", "Privacy overview")]
         ),
         Window.new(
           "big-tech-platforms",
           dgettext("landing", "Big Tech Platforms"),
           :icon_warning,
           width: 460,
           body: &big_tech_platforms/1,
           status: [dgettext("landing", "Their rules")]
         ),
         # Wider than its neighbour because it says more: push, the browser
         # cookie and the optional address each added a section, and at the
         # old width the window had become a column of text taller than it
         # was wide.
         Window.new("retro-hex-chat", dgettext("landing", "Retro Hex Chat"), :icon_shield,
           width: 680,
           body: &retro_hex_chat/1,
           status: [dgettext("landing", "Your rules")]
         ),
         Window.new(
           "side-by-side-comparison",
           dgettext("landing", "Side-by-side comparison"),
           :icon_lock,
           width: 900,
           body: &side_by_side_comparison/1,
           assigns: %{
             theirs: dgettext("landing", "Discord / Slack / Telegram"),
             rows: [
               {dgettext("landing", "Who owns the server?"), dgettext("landing", "A corporation"),
                dgettext("landing", "You")},
               {dgettext("landing", "Where are messages stored?"),
                dgettext("landing", "Their cloud, their terms"),
                dgettext("landing", "Your server, your database")},
               {dgettext("landing", "Voice and video calls"),
                dgettext("landing", "Routed through their servers"),
                dgettext(
                  "landing",
                  "Private P2P via WebRTC; channel conferences via your self-hosted SFU"
                )},
               {dgettext("landing", "Can they read your messages?"),
                dgettext("landing", "Yes — and they do"),
                dgettext("landing", "Access is controlled by your own server and policies")},
               {dgettext("landing", "Data used for AI training?"),
                dgettext("landing", "Often, and without consent"),
                dgettext("landing", "Never. Your data is yours.")},
               {dgettext("landing", "Can they ban your community?"),
                dgettext("landing", "Yes, at any time"),
                dgettext("landing", "No — you own the server")},
               {dgettext("landing", "Source code"),
                dgettext("landing", "Closed. Trust them blindly."),
                dgettext("landing", "Open source. Audit it yourself.")}
             ]
           },
           status: [dgettext("landing", "Your data. Your rules.")]
         )
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

  embed_templates "privacy/*"
end
