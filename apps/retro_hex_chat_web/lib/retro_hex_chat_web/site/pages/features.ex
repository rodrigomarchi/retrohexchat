defmodule RetroHexChatWeb.Site.Pages.Features do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.Diagrams

  import RetroHexChatWeb.Components.UI.Landing.GameCards,
    only: [arcade_game_links: 1, catalogue_link: 1]

  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    arcade_count = length(GameCatalog.list(:arcade))

    {:ok,
     %{
       active_page: :features,
       catalogue_path: PublicPages.localized_path("/games"),
       arcade: GameCatalog.arcade_cards(),
       mirc_commands_path: PublicPages.localized_path(PublicPages.path(:mirc_commands)),
       windows: [
         Window.new("intro", dgettext("landing", "Retro Hex Chat Features"), :icon_chat,
           width: 640,
           taskbar_label: dgettext("landing", "Features"),
           body: &page_intro/1,
           assigns: %{
             heading_id: "features-heading",
             description:
               dgettext(
                 "landing",
                 "Explore the public chat features: real-time channels, virtual spaces, private P2P voice and video calls, channel conferences, file transfer, games, bots, IRC-style commands, and built-in help."
               )
           },
           status: [dgettext("landing", "Feature overview")]
         ),
         Window.new("real-time-chat", dgettext("landing", "Real-time Chat"), :icon_chat,
           width: 460,
           body: &real_time_chat/1,
           status: [{:check, dgettext("landing", "Live")}]
         ),
         Window.new("channels", dgettext("landing", "Channels"), :icon_channels,
           width: 420,
           body: &channels/1,
           status: [{:check, dgettext("landing", "Flexible")}]
         ),
         Window.new("virtual-spaces", dgettext("landing", "Virtual Spaces"), :icon_group_view,
           width: 460,
           body: &virtual_spaces/1,
           status: [{:check, dgettext("landing", "Spatial chat")}]
         ),
         Window.new(
           "channel-conferences",
           dgettext("landing", "Channel Conferences"),
           :icon_conference,
           width: 400,
           body: &channel_conferences/1,
           status: [{:check, dgettext("landing", "Group call")}]
         ),
         Window.new(
           "private-p2p-calls-files",
           dgettext("landing", "Private P2P Calls & Files"),
           :icon_p2p,
           width: 380,
           taskbar_label: dgettext("landing", "Private P2P"),
           body: &private_p2p_calls_files/1,
           status: [{:check, dgettext("landing", "Encrypted")}]
         ),
         Window.new("multiplayer-games", dgettext("landing", "Multiplayer Games"), :icon_joystick,
           width: 520,
           body: &multiplayer_games/1,
           status: [{:check, dgettext("landing", "34 games")}]
         ),
         Window.new("solo-arcade", dgettext("landing", "Arcade"), :icon_game_arcade,
           width: 700,
           body: &solo_arcade/1,
           status: [
             {:check,
              dngettext("landing", "%{count} game", "%{count} games", arcade_count,
                count: arcade_count
              )}
           ]
         ),
         Window.new("bots", dgettext("landing", "Bots"), :icon_robot,
           width: 460,
           body: &bots/1,
           status: [{:check, dgettext("landing", "Extensible")}]
         ),
         Window.new("administration", dgettext("landing", "Administration"), :icon_rules,
           width: 560,
           body: &administration/1,
           status: [{:check, dgettext("landing", "Full control")}]
         ),
         Window.new("built-in-help", dgettext("landing", "Built-in Help"), :icon_question,
           width: 460,
           body: &built_in_help/1,
           status: [{:check, dgettext("landing", "Self-documented")}]
         ),
         Window.new("irc-commands", dgettext("landing", "IRC Commands"), :icon_terminal,
           width: 460,
           body: &irc_commands/1,
           status: [{:check, dgettext("landing", "50+ commands")}]
         )
       ],
       canonical_path: "/features",
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), "/"},
           {dgettext("landing", "Features"), "/features"}
         ])
       ],
       page_title: dgettext("landing", "Features — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Explore real-time channels, Spaces, private P2P calls, channel conferences, 34 multiplayer games, classic arcade games, bots, commands, and help."
         )
     }}
  end

  embed_templates "features/*"
end
