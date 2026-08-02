defmodule RetroHexChatWeb.LandingLive.Privacy do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :privacy,
       windows: [
         %{id: "intro", label: dgettext("landing", "Privacy"), icon: :icon_lock},
         %{
           id: "big-tech-platforms",
           label: dgettext("landing", "Big Tech Platforms"),
           icon: :icon_warning
         },
         %{
           id: "retro-hex-chat",
           label: dgettext("landing", "Retro Hex Chat"),
           icon: :icon_hex_stone
         },
         %{
           id: "side-by-side-comparison",
           label: dgettext("landing", "Side-by-side comparison"),
           icon: :icon_group_view
         }
       ],
       canonical_path: "/privacy",
       page_title:
         dgettext("landing", "Privacy Comparison — Retro Hex Chat vs Discord, Slack & Telegram"),
       page_description:
         dgettext(
           "landing",
           "Side-by-side privacy comparison: data ownership, call routing, message access, AI training, and source code transparency."
         )
     )}
  end
end
