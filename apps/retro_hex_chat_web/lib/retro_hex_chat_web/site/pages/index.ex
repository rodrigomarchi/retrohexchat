defmodule RetroHexChatWeb.Site.Pages.Index do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChat.Channels.Server
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    description =
      dgettext(
        "landing",
        "Run your own chat server with channels, virtual spaces, private P2P calls, channel conferences, bots, and retro games. Open source, self-hosted, and MIT licensed."
      )

    chat_path = Paths.chat_path(Server.default_channel())

    {:ok,
     %{
       active_page: :home,
       window_title: dgettext("landing", "Welcome"),
       enter_chat_path: chat_path,
       sign_up_path: Paths.visitor_sign_in_path(:chat, chat_path),
       windows: [
         %{
           id: "retro-hex-chat-welcome",
           label: dgettext("landing", "Welcome"),
           icon: :icon_hex_stone
         },
         %{id: "c-desktop", label: dgettext("landing", "C:\\Desktop"), icon: :icon_folder},
         %{id: "the-problem", label: dgettext("landing", "The Problem"), icon: :icon_warning},
         %{id: "the-solution", label: dgettext("landing", "The Solution"), icon: :icon_lightbulb},
         %{
           id: "private-p2p-no-media-middleman",
           label: dgettext("landing", "Private P2P"),
           icon: :icon_p2p
         },
         %{
           id: "three-ways-to-be-together",
           label: dgettext("landing", "Three ways"),
           icon: :icon_community
         },
         %{
           id: "multiplayer-games",
           label: dgettext("landing", "Multiplayer Games"),
           icon: :icon_joystick
         },
         %{id: "solo-arcade", label: dgettext("landing", "Solo Arcade"), icon: :icon_joystick}
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

  embed_templates "index.html"

  @impl RetroHexChatWeb.Site.Page
  def render(assigns), do: index(assigns)
end
