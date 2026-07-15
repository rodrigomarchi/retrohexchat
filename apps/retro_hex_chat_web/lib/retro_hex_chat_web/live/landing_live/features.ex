defmodule RetroHexChatWeb.LandingLive.Features do
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
       active_page: :features,
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
