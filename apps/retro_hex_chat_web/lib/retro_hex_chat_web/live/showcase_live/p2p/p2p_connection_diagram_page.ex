defmodule RetroHexChatWeb.ShowcaseLive.P2P.P2PConnectionDiagramPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram
  import RetroHexChatWeb.ShowcaseHelpers

  @local_info %{
    browser: dgettext("showcase", "Chrome 145.0"),
    os: dgettext("showcase", "macOS 10.15"),
    screen: "2560x1440",
    language: "en-US",
    timezone: "America/Sao_Paulo",
    cores: 14,
    color_depth: 24
  }

  @peer_info %{
    browser: dgettext("showcase", "Firefox 148.0"),
    os: dgettext("showcase", "Linux Ubuntu"),
    screen: "1920x1080",
    language: "pt-BR",
    timezone: "America/Sao_Paulo",
    cores: 8,
    color_depth: 30
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "P2P Connection Diagram"),
       active_page: "p2p-connection-diagram"
     )}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:local_info, @local_info)
      |> assign(:peer_info, @peer_info)

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">
        {dgettext("showcase", "P2P Connection Diagram")}
      </h2>

      <.showcase_card
        title={dgettext("showcase", "Compact — Waiting")}
        description="Default compact diagram used by all P2P lobby states."
      >
        <.p2p_connection_strip
          nickname="you"
          peer_nick="alice"
          peer_online={false}
          session_status="pending"
          local_info={@local_info}
          peer_info={%{}}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Compact — Ready")}
        description="Both peers are present and ready to choose an action."
      >
        <.p2p_connection_strip
          nickname="you"
          peer_nick="bob"
          peer_online={true}
          session_status="lobby"
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Compact — Video Call")}
        description="Compact state while a call is active."
      >
        <.p2p_connection_strip
          nickname="you"
          peer_nick="carol"
          peer_online={true}
          session_status="active"
          webrtc_state="Connected"
          call={%{type: "video", duration: "05:12"}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Compact — File Transfer")}
        description="Compact state while transfer progress is active."
      >
        <.p2p_connection_strip
          nickname="you"
          peer_nick="dave"
          peer_online={true}
          session_status="active"
          webrtc_state="Connected"
          file_transfer={%{status: "transferring", percent: 42}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Expanded — Ready")}
        description="Full diagram shown after expanding from compact mode."
      >
        <.p2p_connection_diagram
          nickname="you"
          peer_nick="bob"
          peer_online={true}
          session_status="lobby"
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Expanded — Video Call")}
        description="Full diagram with active call state."
      >
        <.p2p_connection_diagram
          nickname="you"
          peer_nick="carol"
          peer_online={true}
          session_status="active"
          webrtc_state="Connected"
          call={%{type: "video", duration: "05:12"}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
