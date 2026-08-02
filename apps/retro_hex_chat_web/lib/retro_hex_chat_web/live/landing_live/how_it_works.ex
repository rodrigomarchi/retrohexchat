defmodule RetroHexChatWeb.LandingLive.HowItWorks do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :how_it_works,
       windows: [
         %{id: "intro", label: dgettext("landing", "How It Works"), icon: :icon_server},
         %{id: "your-server", label: dgettext("landing", "Your Server"), icon: :icon_server},
         %{
           id: "private-p2p-connections",
           label: dgettext("landing", "Private P2P Connections"),
           icon: :icon_p2p
         },
         %{
           id: "virtual-spaces",
           label: dgettext("landing", "Virtual Spaces"),
           icon: :icon_joystick
         },
         %{
           id: "channel-conferences",
           label: dgettext("landing", "Channel Conferences"),
           icon: :icon_chat
         },
         %{
           id: "privacy-comparison",
           label: dgettext("landing", "Privacy Comparison"),
           icon: :icon_lock
         },
         %{
           id: "security-layers",
           label: dgettext("landing", "Security Layers"),
           icon: :icon_shield
         }
       ],
       canonical_path: "/how-it-works",
       page_title:
         dgettext("landing", "How Retro Hex Chat Works — Server, Spaces, Calls & Privacy"),
       page_description:
         dgettext(
           "landing",
           "Learn how Retro Hex Chat works: self-hosted chat, virtual Spaces, private WebRTC P2P sessions, channel conferences, privacy, and security."
         )
     )}
  end
end
