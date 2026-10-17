defmodule RetroHexChatWeb.Site.Pages.Index do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.Diagrams
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChat.Channels.Server
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    description =
      dgettext(
        "landing",
        "Run your own chat server with channels, virtual spaces, private P2P calls, channel conferences, bots, and retro games. Open source, self-hosted, and MIT licensed."
      )

    {:ok,
     %{
       active_page: :home,
       sign_up_path: Paths.visitor_sign_in_path(:chat, Paths.chat_path(Server.default_channel())),
       windows: [
         Window.new(
           "retro-hex-chat-welcome",
           dgettext("landing", "Retro Hex Chat — Welcome"),
           :icon_chat,
           width: 560,
           taskbar_label: dgettext("landing", "Welcome"),
           body: &retro_hex_chat_welcome/1,
           status: [dgettext("landing", "Ready"), dgettext("landing", "v0.1.0")]
         ),
         Window.new("the-problem", dgettext("landing", "The Problem"), :icon_warning,
           width: 560,
           body: &the_problem/1,
           status: [dgettext("landing", "C:\\TRUTH\\")]
         ),
         Window.new("the-solution", dgettext("landing", "The Solution"), :icon_chat,
           width: 620,
           body: &the_solution/1,
           status: [{:check, dgettext("landing", "Ready")}]
         ),
         Window.new(
           "private-p2p-no-media-middleman",
           dgettext("landing", "Private P2P. No media middleman."),
           :icon_p2p,
           width: 680,
           taskbar_label: dgettext("landing", "Private P2P"),
           body: &private_p2p_no_media_middleman/1,
           status: [{:check, dgettext("landing", "Got it")}]
         ),
         Window.new(
           "three-ways-to-be-together",
           dgettext("landing", "Three ways to be together"),
           :icon_channels,
           width: 680,
           taskbar_label: dgettext("landing", "Three ways"),
           body: &three_ways_to_be_together/1,
           status: [{:check, dgettext("landing", "Chat / Space / Conference")}]
         ),
         Window.new("multiplayer-games", dgettext("landing", "Multiplayer Games"), :icon_joystick,
           width: 460,
           body: &multiplayer_games/1,
           status: [{:check, dgettext("landing", "34 games")}]
         ),
         Window.new("solo-arcade", dgettext("landing", "Solo Arcade"), :icon_game_arcade,
           width: 420,
           body: &solo_arcade/1,
           status: [{:check, dgettext("landing", "18 games")}]
         )
       ],
       canonical_path: "/",
       page_title:
         dgettext("landing", "Retro Hex Chat — Self-hosted chat, spaces, calls and games"),
       page_description: description,
       # The application is one entity, so it is described here and nowhere
       # else. The other six landing pages describe themselves instead.
       json_ld: [
         SEO.website_json_ld(),
         SEO.organization_json_ld(),
         SEO.software_application_json_ld(description)
       ]
     }}
  end

  embed_templates "index/*"
end
