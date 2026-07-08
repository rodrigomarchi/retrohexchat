defmodule RetroHexChatWeb.App.LobbyLive.Components.MediaIsland do
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
  pushes the hook's media commands and its own `window_command` (C3), and mirrors a
  `{type, duration, quality_label}` summary to the host for the taskbar badge and
  the Statistics-window connection strip (C2). Device fallbacks and errors bubble
  to the host (`{:p2p_feature_notice, :call, text}`) for its chat sink (C1).

  Host-agnostic: the standalone lobby and the in-chat P2P session mount the
  same island — `window_id` names the desktop window it drives ("call" in the
  lobby, "p2p-call" in the chat).

  WebRTC negotiation is single-offerer and lives in the host/JS backbone — the
  island only asks for media via hook push-events; it never touches offer/answer.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Lobby.MediaPanel

  alias RetroHexChat.Lobby

  @pubsub RetroHexChat.PubSub
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
       local_muted: false,
       local_camera_off: false,
       peer_muted: false,
       peer_camera_off: false,
       peer_media: %{audio: false, video: false},
       devices: nil,
       connected: false,
       nickname: nil,
       peer_nick: nil,
       token: nil,
       user_id: nil,
       window_id: "call"
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

  def update(%{action: {:peer_media_changed, payload}} = assigns, socket) do
    socket = assign_context(socket, assigns)
    socket = assign(socket, peer_media: %{audio: payload.audio, video: payload.video})
    {:ok, surface_peer_media(socket, payload.audio or payload.video)}
  end

  def update(assigns, socket), do: {:ok, assign_context(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full">
      <.media_panel
        connected={@connected}
        call={@call}
        call_layout={@call_layout}
        peer_nick={@peer_nick}
        nickname={@nickname}
        local_muted={@local_muted}
        local_camera_off={@local_camera_off}
        peer_media={@peer_media}
        peer_camera_off={@peer_camera_off}
        peer_muted={@peer_muted}
        devices={@devices}
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
      window_id: Map.get(assigns, :window_id, socket.assigns.window_id)
    )
  end

  # --- Media events (forwarded from the host; the hook pushes to the root LV) ---

  @spec media_event(Phoenix.LiveView.Socket.t(), String.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp media_event(socket, "start_call", %{"type" => "video"}) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, true, true)

    socket
    |> push_event("lobby_media_start_video", %{})
    |> push_event("window_command", %{action: "open", id: socket.assigns.window_id})
  end

  defp media_event(socket, "start_call", %{"type" => "audio"}) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, true, false)

    socket
    |> push_event("lobby_media_start_audio", %{})
    |> push_event("window_command", %{action: "open", id: socket.assigns.window_id})
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
      peer_muted: false,
      peer_camera_off: false
    )
    |> push_event("window_command", %{action: "close", id: socket.assigns.window_id})
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
       when layout in ~w(focus side_by_side maximized) do
    assign(socket, call_layout: layout)
  end

  defp media_event(socket, "set_call_layout", _params), do: socket

  defp media_event(socket, "lobby_media_devices_listed", payload) do
    assign(socket, devices: payload)
  end

  defp media_event(socket, "lobby_media_device_fallback", %{"message" => message}) do
    send(self(), {:p2p_feature_notice, :call, message})
    socket
  end

  defp media_event(socket, "lobby_media_error", _params) do
    send(
      self(),
      {:p2p_feature_notice, :call,
       dgettext("lobby", "Could not access your microphone or camera.")}
    )

    socket |> assign(call: nil) |> summarize()
  end

  defp media_event(socket, _name, _params), do: socket

  # --- surface_peer_media (auto-join) ---

  # The peer's media turned on. If we are not in the call yet, auto-join and open our
  # own media by default to match the call: mic always, plus camera when the peer is
  # sharing video. The user can mute or turn the camera off afterwards — starting open
  # keeps the controls honest (an "on" icon means a live track). The hook acquires the
  # media and echoes `lobby_media_call_started`, which sets the real call state; if it
  # cannot (permission denied), it falls back to a pure receiver. While the interim
  # "receiving" state stands, the surface still renders because the peer is sharing. If
  # we are already in, just keep the window surfaced.
  @spec surface_peer_media(Phoenix.LiveView.Socket.t(), boolean()) ::
          Phoenix.LiveView.Socket.t()
  defp surface_peer_media(socket, true) do
    if is_nil(socket.assigns.call) do
      start_event =
        if socket.assigns.peer_media.video,
          do: "lobby_media_start_video",
          else: "lobby_media_start_audio"

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
      |> push_event(start_event, %{auto: true})
      |> push_event("window_command", %{action: "open", id: socket.assigns.window_id})
      |> summarize()
    else
      push_event(socket, "window_command", %{action: "open", id: socket.assigns.window_id})
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

  # The host owns the cross-cutting read-model (taskbar badge + Statistics strip);
  # mirror just the fields those readers need. The duration ticks every second, so
  # keep this cheap.
  @spec summarize(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp summarize(socket) do
    summary =
      case socket.assigns.call do
        nil -> nil
        call -> Map.take(call, [:type, :duration, :quality_label])
      end

    send(self(), {:feature_summary, :call, summary})
    socket
  end
end
