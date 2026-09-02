defmodule RetroHexChatWeb.P2PLive.Components.P2PMediaIsland do
  @moduledoc """
  Audio/video call island — owner of the whole media state (`call`, `call_layout`,
  the local/peer mute and camera flags, `peer_media`, `devices`) and the body of the
  "Call" window.

  Media is self-controlled: each peer drives their own mic/camera. The island owns
  every media event — the `LobbyMediaHook` pushes them to the root LiveView, which
  forwards the family here as `{:media_event, name, params}`; the three peer-state
  PubSub events arrive the same way through host adapters. The island runs
  `surface_peer_media` (auto-joining a call when the peer turns media on), records
  media presence with `Lobby.set_media`, broadcasts its own mute/camera changes,
  pushes the hook's media commands (C3), and mirrors a
  `{type, duration, quality_label}` summary to the host for the taskbar badge and
  the Stats section connection strip (C2). Device fallbacks and errors bubble
  to the host (`{:p2p_feature_notice, :call, text}`) for its chat sink (C1).
  Whenever call activity needs to surface, the island asks the host to select the
  Call section of the single P2P console.

  WebRTC negotiation is single-offerer and lives in the host/JS backbone — the
  island only asks for media via hook push-events; it never touches offer/answer.
  """
  use RetroHexChatWeb, :live_component

  require Logger

  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.Components.UI.P2P.CallPanel

  @pubsub RetroHexChat.PubSub
  @reaction_ttl_ms 2400
  @valid_reactions ~w(heart thumbs_up clap laugh sparkle)
  # Distinct from the media panel's own `id="lobby-media"` hook element inside it.
  @id "lobby-media-island"

  @doc "Stable DOM/component id used by the host for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       call: nil,
       call_layout: "focus",
       self_view: "pip",
       local_muted: false,
       local_camera_off: false,
       screen_sharing: false,
       peer_muted: false,
       peer_camera_off: false,
       peer_screen_sharing: false,
       peer_media: %{audio: false, video: false},
       reactions: [],
       devices: nil,
       connected: false,
       mini: false,
       device_preferences: %{},
       media_mode: "video",
       nickname: nil,
       peer_nick: nil,
       token: nil,
       user_id: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:media_event, name, params}} = assigns, socket) do
    {:ok, socket |> assign_context(assigns) |> media_event(name, params)}
  end

  def update(%{action: {:peer_mute, muted}} = assigns, socket) do
    {:ok,
     socket
     |> assign_context(assigns)
     |> assign(peer_muted: muted)
     |> push_event("lobby_media_peer_muted", %{muted: muted})}
  end

  def update(%{action: {:peer_camera, off}} = assigns, socket) do
    {:ok,
     socket
     |> assign_context(assigns)
     |> assign(peer_camera_off: off)
     |> push_event("lobby_media_peer_camera", %{off: off})}
  end

  def update(%{action: {:peer_screen_share, active}} = assigns, socket) do
    socket =
      socket
      |> assign_context(assigns)
      |> assign(peer_screen_sharing: active)
      |> maybe_focus_shared_screen(active)

    {:ok, socket}
  end

  def update(%{action: {:peer_reaction, reaction, reaction_id}} = assigns, socket) do
    {:ok, socket |> assign_context(assigns) |> add_reaction(:peer, reaction, reaction_id)}
  end

  def update(%{action: {:clear_reaction, reaction_id}} = assigns, socket) do
    socket = assign_context(socket, assigns)
    {:ok, assign(socket, reactions: reject_reaction(socket.assigns.reactions, reaction_id))}
  end

  def update(%{action: {:peer_media_changed, payload}} = assigns, socket) do
    socket = assign_context(socket, assigns)
    socket = assign(socket, peer_media: %{audio: payload.audio, video: payload.video})

    socket =
      push_event(socket, "lobby_media_peer_media", %{
        audio: payload.audio,
        video: payload.video
      })

    {:ok, surface_peer_media(socket, payload.audio or payload.video)}
  end

  def update(assigns, socket), do: {:ok, assign_context(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full">
      <CallPanel.call_panel
        connected={@connected}
        call={@call}
        call_layout={@call_layout}
        self_view={@self_view}
        peer_nick={@peer_nick}
        nickname={@nickname}
        local_muted={@local_muted}
        local_camera_off={@local_camera_off}
        screen_sharing={@screen_sharing}
        peer_media={@peer_media}
        peer_camera_off={@peer_camera_off}
        peer_muted={@peer_muted}
        peer_screen_sharing={@peer_screen_sharing}
        reactions={@reactions}
        devices={@devices}
        media_mode={@media_mode}
        mini={@mini}
        show_header={false}
      />
    </div>
    """
  end

  @spec assign_context(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_context(socket, assigns) do
    assign(socket,
      connected: Map.get(assigns, :connected, socket.assigns.connected),
      nickname: Map.get(assigns, :nickname, socket.assigns.nickname),
      peer_nick: Map.get(assigns, :peer_nick, socket.assigns.peer_nick),
      token: Map.get(assigns, :token, socket.assigns.token),
      user_id: Map.get(assigns, :user_id, socket.assigns.user_id),
      self_view: Map.get(assigns, :self_view, socket.assigns.self_view),
      mini: Map.get(assigns, :mini, socket.assigns.mini),
      device_preferences:
        Map.get(assigns, :device_preferences, socket.assigns.device_preferences),
      media_mode: Map.get(assigns, :media_mode, socket.assigns.media_mode)
    )
  end

  # --- Media events (forwarded from the host; the hook pushes to the root LV) ---

  @spec media_event(Phoenix.LiveView.Socket.t(), String.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp media_event(socket, "start_call", %{"type" => "video"}) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, true, true)

    socket
    |> push_event("lobby_media_start_video", media_start_payload(socket))
    |> surface_call()
  end

  defp media_event(socket, "start_call", %{"type" => "audio"}) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, true, false)

    socket
    |> push_event("lobby_media_start_audio", media_start_payload(socket))
    |> surface_call()
  end

  defp media_event(socket, "join_call", _params) do
    socket
    |> push_event("lobby_media_join", %{})
    |> surface_call()
  end

  # The media hook reports its self-controlled send state for every change: starting
  # a call, or an auto-joined receiver later enabling mic/camera. The `audio_on`/
  # `video_on` flags describe what THIS peer is sending now.
  defp media_event(socket, "lobby_media_call_started", params) do
    type = params["type"] || "audio"
    audio_on = Map.get(params, "audio_on", true)
    video_on = Map.get(params, "video_on", type == "video")
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, audio_on, video_on)

    call =
      Map.merge(socket.assigns.call || %{}, %{
        type: type,
        audio_on: audio_on,
        video_on: video_on,
        duration: (socket.assigns.call || %{})[:duration] || "00:00:00",
        muted: socket.assigns.local_muted,
        camera_off: socket.assigns.local_camera_off
      })

    socket |> assign(call: call) |> summarize()
  end

  # The X on the Call window asks the hook to tear the call down and echo back so
  # `lobby_media_call_ended` clears our state and closes the window.
  defp media_event(socket, "end_call", _params) do
    push_event(socket, "lobby_media_end_call", %{notify: true})
  end

  defp media_event(socket, "lobby_media_call_ended", _params) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, false, false)

    socket
    |> assign(
      call: nil,
      call_layout: "focus",
      local_muted: false,
      local_camera_off: false,
      screen_sharing: false,
      peer_muted: false,
      peer_camera_off: false,
      peer_screen_sharing: false
    )
    |> summarize()
  end

  defp media_event(socket, "lobby_media_mute_changed", %{"muted" => muted}) do
    broadcast(socket, "lobby_peer_mute", %{muted: muted, from: socket.assigns.user_id})
    merge_call(socket, [local_muted: muted], %{muted: muted})
  end

  defp media_event(socket, "lobby_media_camera_changed", %{"off" => off}) do
    broadcast(socket, "lobby_peer_camera", %{off: off, from: socket.assigns.user_id})
    merge_call(socket, [local_camera_off: off], %{camera_off: off})
  end

  defp media_event(socket, "lobby_media_screen_share_changed", %{"active" => active}) do
    broadcast(socket, "lobby_peer_screen_share", %{active: active, from: socket.assigns.user_id})

    socket
    |> merge_call([screen_sharing: active], %{screen_sharing: active})
    |> maybe_focus_shared_screen(active)
    |> summarize()
  end

  defp media_event(socket, "send_call_reaction", %{"reaction" => reaction})
       when reaction in @valid_reactions do
    reaction_id = "p2p-reaction-#{System.unique_integer([:positive])}"

    broadcast(socket, "lobby_peer_reaction", %{
      reaction: reaction,
      reaction_id: reaction_id,
      from: socket.assigns.user_id
    })

    add_reaction(socket, :local, reaction, reaction_id)
  end

  defp media_event(socket, "send_call_reaction", _params), do: socket

  defp media_event(socket, "lobby_media_duration_tick", %{"formatted" => formatted}) do
    socket
    |> assign(call: Map.merge(socket.assigns.call || %{}, %{duration: formatted}))
    |> summarize()
  end

  defp media_event(socket, "lobby_media_quality_update", %{"label" => label} = p) do
    call =
      Map.merge(socket.assigns.call || %{}, %{quality_level: p["level"], quality_label: label})

    socket |> assign(call: call) |> summarize()
  end

  defp media_event(socket, "media_select_preset", %{"preset" => preset}) do
    push_event(socket, "lobby_media_set_preset", %{preset: preset})
  end

  defp media_event(socket, "set_call_layout", %{"layout" => layout})
       when layout in ~w(auto focus split speaker compact side_by_side maximized) do
    assign(socket, call_layout: layout)
  end

  defp media_event(socket, "set_call_layout", _params), do: socket

  defp media_event(socket, "cycle_call_self_view", _params) do
    assign(socket, self_view: next_self_view(socket.assigns.self_view))
  end

  defp media_event(socket, "cycle_call_layout", _params) do
    assign(socket, call_layout: next_layout(socket.assigns.call_layout))
  end

  defp media_event(socket, "lobby_media_devices_listed", payload) do
    assign(socket, devices: payload)
  end

  defp media_event(socket, "lobby_media_device_fallback", %{"message" => message}) do
    send(self(), {:p2p_feature_notice, :call, message, scope: :local})
    socket
  end

  defp media_event(socket, "lobby_media_error", _params) do
    send(
      self(),
      {:p2p_feature_notice, :call,
       dgettext("lobby", "Could not access your microphone or camera."), scope: :local}
    )

    socket |> assign(call: nil) |> summarize()
  end

  # Not a silent swallow: an event with no clause here is a hook and a server
  # that have drifted apart, and the only way that ever surfaces is somebody
  # noticing a control doing nothing. Logging it is the difference between a
  # bug with a breadcrumb and a bug with none.
  defp media_event(socket, name, _params) do
    Logger.debug("P2PMediaIsland ignored media event #{inspect(name)}")
    socket
  end

  # --- surface_peer_media (auto-join) ---

  # The peer's media turned on. If we are not in the call yet, surface the call and
  # honor this side's setup posture: receive-only joins without capture, audio starts
  # mic only, and the default video posture keeps matching the peer's active media.
  # The hook echoes `lobby_media_call_started` once it acquires local tracks.
  @spec surface_peer_media(Phoenix.LiveView.Socket.t(), boolean()) ::
          Phoenix.LiveView.Socket.t()
  defp surface_peer_media(socket, true) do
    if is_nil(socket.assigns.call) do
      call = %{
        type: "receiving",
        audio_on: false,
        video_on: false,
        duration: "00:00:00",
        muted: false,
        camera_off: false
      }

      socket
      |> assign(call: call, local_muted: false, local_camera_off: false)
      |> push_peer_media_surface_command()
      |> surface_call()
      |> summarize()
    else
      surface_call(socket)
    end
  end

  # The peer turned everything off. If we were only receiving (sending nothing),
  # there is no media left for us, so leave the call; otherwise stay as we are.
  defp surface_peer_media(socket, false) do
    call = socket.assigns.call
    sending? = call != nil and (call[:audio_on] or call[:video_on])

    if call != nil and not sending? do
      push_event(socket, "lobby_media_end_call", %{notify: true})
    else
      socket
    end
  end

  defp surface_call(socket) do
    send(self(), {:p2p_console_section, "call"})
    socket
  end

  # --- Helpers ---

  # Set a local flag (mute/camera) and mirror it into the active call map in one go.
  @spec merge_call(Phoenix.LiveView.Socket.t(), keyword(), map()) :: Phoenix.LiveView.Socket.t()
  defp merge_call(socket, flags, patch) do
    call = Map.merge(socket.assigns.call || %{}, patch)
    assign(socket, Keyword.put(flags, :call, call))
  end

  @spec broadcast(Phoenix.LiveView.Socket.t(), String.t(), map()) :: :ok
  defp broadcast(socket, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "lobby:#{socket.assigns.token}", %{
      event: event,
      payload: payload,
      token: socket.assigns.token
    })
  end

  @spec media_start_payload(Phoenix.LiveView.Socket.t()) :: map()
  defp media_start_payload(socket) do
    %{device_preferences: socket.assigns.device_preferences || %{}}
  end

  defp push_peer_media_surface_command(%{assigns: %{media_mode: "receive"}} = socket) do
    push_event(socket, "lobby_media_join", %{expected_video: socket.assigns.peer_media.video})
  end

  defp push_peer_media_surface_command(%{assigns: %{media_mode: "audio"}} = socket) do
    push_event(socket, "lobby_media_start_audio", %{
      auto: true,
      expected_video: socket.assigns.peer_media.video
    })
  end

  defp push_peer_media_surface_command(socket) do
    event =
      if socket.assigns.peer_media.video,
        do: "lobby_media_start_video",
        else: "lobby_media_start_audio"

    push_event(socket, event, %{auto: true, expected_video: socket.assigns.peer_media.video})
  end

  # The host owns the cross-cutting read-model (taskbar badge + Statistics strip);
  # mirror just the fields those readers need. The duration ticks every second, so
  # keep this cheap.
  @spec summarize(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp summarize(socket) do
    summary =
      case socket.assigns.call do
        nil -> nil
        call -> Map.take(call, [:type, :duration, :quality_label, :screen_sharing])
      end

    send(self(), {:feature_summary, :call, summary})
    socket
  end

  @spec add_reaction(Phoenix.LiveView.Socket.t(), :local | :peer, String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp add_reaction(socket, source, reaction, reaction_id) do
    Process.send_after(self(), {:p2p_call_reaction_timeout, reaction_id}, @reaction_ttl_ms)

    reaction = %{
      id: reaction_id,
      source: source,
      reaction: reaction
    }

    assign(socket, reactions: [reaction | reject_reaction(socket.assigns.reactions, reaction_id)])
  end

  defp reject_reaction(reactions, reaction_id) do
    Enum.reject(reactions, &(&1.id == reaction_id))
  end

  @spec next_self_view(String.t()) :: String.t()
  defp next_self_view("tile"), do: "pip"
  defp next_self_view("pip"), do: "hidden"
  defp next_self_view(_hidden_or_unknown), do: "tile"

  @spec next_layout(String.t()) :: String.t()
  defp next_layout("auto"), do: "focus"
  defp next_layout("focus"), do: "split"
  defp next_layout("split"), do: "speaker"
  defp next_layout("speaker"), do: "compact"
  defp next_layout(_compact_or_unknown), do: "auto"

  @spec maybe_focus_shared_screen(Phoenix.LiveView.Socket.t(), boolean()) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_focus_shared_screen(socket, true), do: assign(socket, call_layout: "focus")
  defp maybe_focus_shared_screen(socket, _inactive), do: socket
end
