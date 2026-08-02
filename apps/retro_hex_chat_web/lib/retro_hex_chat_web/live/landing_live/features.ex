defmodule RetroHexChatWeb.LandingLive.Features do
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
       active_page: :features,
       windows: [
         %{id: "intro", label: dgettext("landing", "Features"), icon: :icon_chat},
         %{id: "real-time-chat", label: dgettext("landing", "Real-time Chat"), icon: :icon_chat},
         %{id: "channels", label: dgettext("landing", "Channels"), icon: :icon_channels},
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
           id: "private-p2p-calls-files",
           label: dgettext("landing", "Private P2P"),
           icon: :icon_p2p
         },
         %{
           id: "multiplayer-games",
           label: dgettext("landing", "Multiplayer Games"),
           icon: :icon_joystick
         },
         %{id: "solo-arcade", label: dgettext("landing", "Solo Arcade"), icon: :icon_joystick},
         %{id: "bots", label: dgettext("landing", "Bots"), icon: :icon_terminal},
         %{
           id: "administration",
           label: dgettext("landing", "Administration"),
           icon: :icon_dialog_admin_console
         },
         %{
           id: "built-in-help",
           label: dgettext("landing", "Built-in Help"),
           icon: :icon_btn_help_topics
         },
         %{id: "irc-commands", label: dgettext("landing", "IRC Commands"), icon: :icon_terminal}
       ],
       canonical_path: "/features",
       page_title: dgettext("landing", "Features — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Explore real-time channels, Spaces, private P2P calls, channel conferences, 34 multiplayer games, 18 arcade games, bots, commands, and help."
         )
     )}
  end
end
