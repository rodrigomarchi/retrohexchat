defmodule RetroHexChatWeb.LandingLive.Index do
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
       active_page: :home,
       canonical_path: "/",
       page_title: dgettext("landing", "Retro Hex Chat — Self-hosted chat with P2P calls"),
       page_description:
         dgettext(
           "landing",
           "Run your own chat server with WebRTC voice and video calls, multiplayer games, bots, and IRC-style channels. Open source, self-hosted, and MIT licensed."
         )
     )}
  end
end
