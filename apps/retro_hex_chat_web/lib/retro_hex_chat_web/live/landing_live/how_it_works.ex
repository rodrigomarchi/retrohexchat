defmodule RetroHexChatWeb.LandingLive.HowItWorks do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :how_it_works,
       canonical_path: "/how-it-works",
       page_title:
         dgettext("landing", "How Retro Hex Chat Works — Server, P2P, Privacy & Security"),
       page_description:
         dgettext(
           "landing",
           "Learn how Retro Hex Chat works: self-hosted server architecture, WebRTC P2P calls, privacy protections, and security layers."
         )
     )}
  end
end
