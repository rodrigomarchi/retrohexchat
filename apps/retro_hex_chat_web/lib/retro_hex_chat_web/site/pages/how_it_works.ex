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
           id: "install-app",
           label: dgettext("landing", "Keep It On Your Device"),
           icon: :icon_hex_stone
         },
         %{
           id: "security-layers",
           label: dgettext("landing", "Security Layers"),
           icon: :icon_shield
         }
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

  embed_templates "how_it_works.html"

  @impl RetroHexChatWeb.Site.Page
  def render(assigns), do: how_it_works(assigns)
end
