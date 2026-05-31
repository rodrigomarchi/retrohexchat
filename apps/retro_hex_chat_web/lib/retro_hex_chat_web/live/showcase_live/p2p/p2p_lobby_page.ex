defmodule RetroHexChatWeb.ShowcaseLive.P2P.P2PLobbyPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.P2PLobby
  import RetroHexChatWeb.Components.UI.P2PSessionEnded
  import RetroHexChatWeb.ShowcaseHelpers

  @local_info %{
    browser: gettext("Chrome 145.0"),
    os: gettext("macOS 10.15"),
    screen: "2560x1440",
    language: "en-US",
    timezone: "America/Sao_Paulo",
    cores: 14,
    color_depth: 24
  }

  @peer_info %{
    browser: gettext("Firefox 148.0"),
    os: gettext("Linux Ubuntu"),
    screen: "1920x1080",
    language: "pt-BR",
    timezone: "America/Sao_Paulo",
    cores: 8,
    color_depth: 30
  }

  @sample_messages [
    %{
      type: "system",
      sender_nick: gettext("System"),
      content: gettext("bob has joined the session")
    },
    %{type: "chat", sender_nick: "you", content: gettext("Hey, ready to connect?")},
    %{type: "chat", sender_nick: "bob", content: gettext("Sure, let's go!")}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("P2P Lobby"), active_page: "p2p-lobby")}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:local_info, @local_info)
      |> assign(:peer_info, @peer_info)
      |> assign(:sample_messages, @sample_messages)

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("P2P Lobby")}</h2>

      <.showcase_card title={gettext("Pending")} description="Waiting for peer to join.">
        <.p2p_lobby
          peer="alice"
          state="pending"
          nickname="you"
          local_info={@local_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Lobby")}
        description="Both peers present. Shows Audio Call, Video Call, Send File buttons."
      >
        <.p2p_lobby
          peer="bob"
          state="lobby"
          nickname="you"
          local_info={@local_info}
          peer_info={@peer_info}
          messages={@sample_messages}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Connecting")}
        description="WebRTC negotiation in progress. Shows progress bar and Cancel button."
      >
        <.p2p_lobby
          peer="carol"
          state="connecting"
          nickname="you"
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Active + Audio Call")}
        description="Active session with an ongoing audio call. Shows media controls."
      >
        <.p2p_lobby
          peer="dave"
          state="active"
          nickname="you"
          webrtc_state="Connected"
          call={%{type: "audio", duration: "02:34"}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Active + Video Call")}
        description="Active session with a video call. Shows video area, camera toggle, quality presets."
      >
        <.p2p_lobby
          peer="dave"
          state="active"
          nickname="you"
          webrtc_state="Connected"
          call={%{type: "video", duration: "05:12", quality_label: "720p"}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Active + File Transfer (sending)")}
        description="Active session with a file transfer in progress."
      >
        <.p2p_lobby
          peer="dave"
          state="active"
          nickname="you"
          webrtc_state="Connected"
          file_transfer={
            %{
              status: "transferring",
              file_name: "project-archive.zip",
              percent: 42,
              speed: "2.4 MB/s",
              formatted_size: "156.3 MB",
              sender_nick: "you"
            }
          }
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Active + File Transfer (receiving offer)")}
        description="Incoming file transfer offer. Shows Accept/Cancel buttons."
      >
        <.p2p_lobby
          peer="dave"
          state="active"
          nickname="you"
          webrtc_state="Connected"
          file_transfer={
            %{
              status: "offer_received",
              file_name: "photo-album.zip",
              percent: 0,
              formatted_size: "89.7 MB",
              sender_nick: "dave"
            }
          }
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Action Request (consent)")}
        description="Bilateral consent banner for incoming action requests."
      >
        <.p2p_lobby
          peer="dave"
          state="lobby"
          nickname="you"
          action_request={%{action_type: "video_call", status: "pending"}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Failed")}
        description="Connection attempt failed. Shows Close Session."
      >
        <.p2p_lobby
          peer="eve"
          state="failed"
          nickname="you"
          webrtc_state="Connection failed"
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("With Privacy & Inactivity Warning")}
        description="Shows privacy toggle and inactivity warning banner."
      >
        <.p2p_lobby
          peer="frank"
          state="lobby"
          nickname="you"
          turn_configured={true}
          turn_only={true}
          inactivity_warning={true}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Session Ended (call ended)")}
        description="Shown to the peer who didn't close. Displays connection diagram, reason, and duration."
      >
        <.p2p_session_ended
          nickname="you"
          peer="dave"
          reason="Call ended."
          duration={185}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Session Ended (user closed)")}
        description="Session closed by the other peer."
      >
        <.p2p_session_ended
          nickname="you"
          peer="alice"
          reason="Session closed by user."
          duration={3723}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Session Ended (file transfer)")}
        description="Session ended after file transfer completed."
      >
        <.p2p_session_ended
          nickname="you"
          peer="bob"
          reason="File transfer completed."
          duration={42}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
