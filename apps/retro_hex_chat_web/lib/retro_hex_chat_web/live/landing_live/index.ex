defmodule RetroHexChatWeb.LandingLive.Index do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :home,
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
       page_description:
         dgettext(
           "landing",
           "Run your own chat server with channels, virtual spaces, private P2P calls, channel conferences, bots, and retro games. Open source, self-hosted, and MIT licensed."
         )
     )}
  end
end
