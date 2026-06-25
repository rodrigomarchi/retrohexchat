defmodule RetroHexChatWeb.App.P2PSessionLive do
  @moduledoc """
  P2P session using app UI components.
  Provides ephemeral chat, peer presence, bilateral consent for actions,
  WebRTC signaling, file transfer, and audio/video calls.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  require Logger

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.P2PLobby

  import RetroHexChatWeb.Components.UI.P2PSessionEnded
  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.Schema.Session
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChatWeb.App.SessionHelpers

  @pubsub RetroHexChat.PubSub
  @call_layouts ~w(focus side_by_side maximized)

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- SessionHelpers.verify_nickname(socket, nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- SessionHelpers.verify_participant(user_id, db_session),
         :ok <- verify_not_terminal(db_session) do
      mount_lobby(socket, token, nickname, user_id, db_session)
    else
      {:expired, reason} ->
        {:ok, assign(socket, expired: true, expired_reason: expired_reason_label(reason))}

      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, push_navigate(socket, to: ~p"/chat")}
    end
  end

  # --- PubSub Handlers ---

  @impl true
  def handle_info(
        %{event: "p2p_status_changed", payload: %{status: "connecting"}},
        socket
      ) do
    Logger.info("P2P connecting: token=#{socket.assigns.token}, role=#{socket.assigns.role}")

    socket =
      socket
      |> assign(session_status: "connecting", action_request: nil)
      |> maybe_start_webrtc()

    {:noreply, socket}
  end

  def handle_info(%{event: "p2p_status_changed", payload: %{status: status}}, socket) do
    if Session.terminal?(status) do
      {:noreply,
       socket
       |> assign(session_closed: true)
       |> push_event("p2p_close_tab", %{})}
    else
      socket = assign(socket, session_status: status)

      socket =
        if status == "active" do
          socket
          |> assign(webrtc_state: "Connected")
          |> maybe_init_file_transfer()
          |> maybe_start_media_if_call()
        else
          socket
        end

      {:noreply, socket}
    end
  end

  def handle_info(%{event: "p2p_lobby_message", payload: msg}, socket) do
    messages = socket.assigns.messages ++ [msg]
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info(
        %{event: "p2p_action_request", payload: %{requester_id: _req_id} = request},
        socket
      ) do
    {:noreply, assign(socket, action_request: request)}
  end

  def handle_info(%{event: "p2p_action_response", payload: response}, socket) do
    action_request =
      (socket.assigns.action_request || %{})
      |> Map.merge(response)
      |> Map.put(:status, if(response[:accepted], do: "accepted", else: "rejected"))

    feedback_msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: action_response_message(response[:action_type], response[:accepted]),
      type: "system",
      timestamp: DateTime.utc_now()
    }

    socket =
      socket
      |> assign(action_request: action_request)
      |> assign(messages: socket.assigns.messages ++ [feedback_msg])

    socket =
      if response[:accepted] do
        socket
        |> assign(accepted_action_type: response[:action_type])
        |> maybe_init_call()
        |> maybe_init_file_transfer()
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(%{event: "p2p_action_expired"}, socket) do
    expired_msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: dgettext("p2p", "Request expired."),
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> assign(action_request: nil)
     |> assign(messages: socket.assigns.messages ++ [expired_msg])}
  end

  def handle_info(%{event: "p2p_session_closed", payload: %{reason: reason}}, socket) do
    if socket.assigns.session_closed do
      # Already handled locally (we initiated the close)
      {:noreply, socket}
    else
      duration_secs = compute_session_duration(socket)

      {:noreply,
       socket
       |> assign(
         session_closed: true,
         session_ended_reason: expired_reason_label(reason),
         session_duration: duration_secs
       )}
    end
  end

  def handle_info(
        %{event: "p2p_inactivity_warning", payload: %{expires_in_seconds: _secs}},
        socket
      ) do
    {:noreply, assign(socket, inactivity_warning: true)}
  end

  def handle_info(
        %{event: "p2p_signal", payload: %{from: from_id} = payload},
        socket
      ) do
    if from_id != socket.assigns.user_id do
      {:noreply, push_event(socket, "p2p_signal", payload)}
    else
      {:noreply, socket}
    end
  end

  # --- Media PubSub Handlers ---

  def handle_info(%{event: "media_mute", payload: %{muted: muted, from: from_id}}, socket) do
    if from_id != socket.assigns.user_id do
      call = Map.merge(socket.assigns.call || %{}, %{peer_muted: muted})

      {:noreply,
       socket
       |> assign(call: call)
       |> push_event("media_peer_muted", %{muted: muted})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "media_camera", payload: %{off: off, from: from_id}}, socket) do
    if from_id != socket.assigns.user_id do
      call = Map.merge(socket.assigns.call || %{}, %{peer_camera_off: off})

      {:noreply,
       socket
       |> assign(call: call)
       |> push_event("media_peer_camera", %{off: off})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "media_call_ended", payload: %{reason: reason}}, socket) do
    if socket.assigns.call do
      msg = %{
        id: System.unique_integer([:positive]),
        sender_nick: dgettext("p2p", "System"),
        content: dgettext("p2p", "Call ended: %{reason}", reason: reason),
        type: "system",
        timestamp: DateTime.utc_now()
      }

      {:noreply,
       socket
       |> assign(
         call: nil,
         stats: nil,
         webrtc_state: "Connected",
         local_muted: false,
         local_camera_off: false,
         call_layout: "focus"
       )
       |> assign(messages: socket.assigns.messages ++ [msg])
       |> push_event("media_end_call", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{event: "media_upgrade_request", payload: %{from: from_id}},
        socket
      ) do
    if from_id != socket.assigns.user_id && socket.assigns.call do
      call = Map.merge(socket.assigns.call, %{upgrade_pending: true})
      {:noreply, assign(socket, call: call)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{event: "media_upgrade_response", payload: %{accepted: accepted, from: from_id}},
        socket
      ) do
    if from_id != socket.assigns.user_id && socket.assigns.call do
      if accepted do
        call = Map.merge(socket.assigns.call, %{upgrade_pending: false, type: "video"})

        {:noreply,
         socket
         |> assign(call: call)
         |> push_event("media_upgrade_accepted", %{})}
      else
        call = Map.merge(socket.assigns.call, %{upgrade_pending: false})

        msg = %{
          id: System.unique_integer([:positive]),
          sender_nick: dgettext("p2p", "System"),
          content: dgettext("p2p", "Video request declined."),
          type: "system",
          timestamp: DateTime.utc_now()
        }

        {:noreply,
         socket
         |> assign(call: call)
         |> assign(messages: socket.assigns.messages ++ [msg])
         |> push_event("media_upgrade_rejected", %{})}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{event: "media_upgrade_failed", payload: %{message: message, from: from_id}},
        socket
      ) do
    if from_id != socket.assigns.user_id && socket.assigns.call do
      {:noreply, rollback_media_upgrade(socket, message)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "p2p_peer_joined", payload: %{user_id: uid}}, socket) do
    if uid != socket.assigns.user_id do
      Phoenix.PubSub.broadcast(
        @pubsub,
        "p2p:#{socket.assigns.token}",
        %{
          event: "p2p_client_info",
          payload: %{from: socket.assigns.user_id, info: socket.assigns.local_info}
        }
      )

      socket = assign(socket, peer_online: true)
      maybe_auto_present(socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{event: "p2p_client_info", payload: %{from: from_id, info: info}},
        socket
      ) do
    if from_id != socket.assigns.user_id do
      {:noreply, assign(socket, peer_info: info)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Client Event Handlers ---

  @impl true
  def handle_event("send_lobby_message", %{"content" => content}, socket) do
    case P2P.send_lobby_message(socket.assigns.token, socket.assigns.user_id, content) do
      :ok ->
        {:noreply, push_event(socket, "p2p_lobby_message_sent", %{form_id: "p2p-chat-form"})}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("request_action", %{"action_type" => type}, socket) do
    P2P.request_action(socket.assigns.token, socket.assigns.user_id, type)
    {:noreply, socket}
  end

  def handle_event("respond_action", %{"accepted" => accepted}, socket) do
    accepted_bool = accepted == "true" or accepted == true

    case P2P.respond_action(socket.assigns.token, socket.assigns.user_id, accepted_bool) do
      :ok when accepted_bool ->
        {:noreply, maybe_init_call(socket)}

      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("close_session", _params, socket) do
    P2P.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("p2p_close_tab", %{})}
  end

  def handle_event("p2p_capabilities", capabilities, socket) do
    caps = %{
      webrtc: Map.get(capabilities, "webrtc", false),
      getUserMedia: Map.get(capabilities, "getUserMedia", false),
      dataChannel: Map.get(capabilities, "dataChannel", false)
    }

    {:noreply, assign(socket, capabilities: caps)}
  end

  def handle_event("p2p_signal", params, socket) do
    Logger.debug("P2P signal relay: type=#{params["type"]}, token=#{socket.assigns.token}")

    rate_limiter = SignalingRateLimit.configured_module()

    with :ok <- rate_limiter.check_signal_rate(socket.assigns.token, socket.assigns.user_id),
         {:ok, validated} <- P2P.validate_signal(params) do
      payload = Map.put(validated, :from, socket.assigns.user_id)

      Phoenix.PubSub.broadcast(
        @pubsub,
        "p2p:#{socket.assigns.token}",
        %{event: "p2p_signal", payload: payload}
      )

      {:noreply, socket}
    else
      {:error, :rate_limited} ->
        {:noreply, maybe_warn_signal_rate_limited(socket)}

      {:error, :invalid_signal} ->
        Logger.warning("P2P invalid signal dropped: token=#{socket.assigns.token}")
        {:noreply, socket}
    end
  end

  def handle_event("p2p_webrtc_ready", _params, socket) do
    {:noreply,
     socket
     |> assign(webrtc_ready: true)
     |> maybe_start_webrtc()}
  end

  def handle_event("media_hook_ready", _params, socket) do
    {:noreply,
     socket
     |> assign(media_ready: true)
     |> maybe_start_media_if_call()}
  end

  def handle_event("file_transfer_ready", _params, socket) do
    {:noreply,
     socket
     |> assign(file_transfer_ready: true)
     |> maybe_push_ft_config()}
  end

  def handle_event("p2p_connected", _params, socket) do
    Logger.info("P2P connected: token=#{socket.assigns.token}")

    case P2P.transition_status(socket.assigns.token, :active) do
      :ok ->
        socket =
          socket
          |> assign(session_status: "active", webrtc_state: "Connected")
          |> maybe_init_file_transfer()
          |> maybe_start_media_if_call()

        {:noreply, socket}

      {:error, _reason} ->
        socket = sync_session_status(socket)
        {:noreply, socket}
    end
  end

  def handle_event("p2p_failed", %{"reason" => reason}, socket) do
    Logger.warning("P2P connection failed: #{reason}, token=#{socket.assigns.token}")

    msg = system_message(connection_failure_message(reason))
    messages = socket.assigns.messages ++ [msg]

    case P2P.transition_status(socket.assigns.token, :failed) do
      :ok ->
        {:noreply,
         assign(socket, session_status: "failed", webrtc_state: "failed", messages: messages)}

      {:error, _reason} ->
        {:noreply, assign(socket, webrtc_state: "failed", messages: messages)}
    end
  end

  def handle_event("p2p_retry", %{"attempt" => attempt}, socket) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "p2p_retry", payload: %{attempt: attempt}}
    )

    {:noreply, assign(socket, webrtc_state: "retrying", retry_attempt: attempt)}
  end

  def handle_event("p2p_state_change", %{"state" => state}, socket) do
    label = SessionHelpers.webrtc_state_label(state, socket.assigns[:retry_attempt])
    {:noreply, assign(socket, webrtc_state: label)}
  end

  def handle_event("p2p_leave", _params, socket) do
    unless socket.assigns[:session_closed] do
      P2P.close_session(socket.assigns.token, socket.assigns.user_id, "tab_closed")
    end

    {:noreply, assign(socket, session_closed: true)}
  end

  # --- File Transfer Events ---

  def handle_event("ft_offer_sent", params, socket) do
    Logger.info(
      "P2P file offer: #{params["file_name"]} (#{params["formatted_size"]}), token=#{socket.assigns.token}"
    )

    ft = %{
      status: "offering",
      file_name: params["file_name"],
      file_size: params["file_size"],
      formatted_size: params["formatted_size"],
      sender_nick: socket.assigns.nickname
    }

    {:noreply, assign(socket, file_transfer: ft, diagram_collapsed: true)}
  end

  def handle_event("ft_offer_received", params, socket) do
    ft = %{
      status: "offer_received",
      file_name: params["file_name"],
      file_size: params["file_size"],
      formatted_size: params["formatted_size"],
      sender_nick: socket.assigns.peer_nick
    }

    {:noreply, assign(socket, file_transfer: ft, diagram_collapsed: true)}
  end

  def handle_event("ft_accept_offer", _params, socket) do
    {:noreply, push_event(socket, "ft_accept", %{})}
  end

  def handle_event("ft_respond", %{"accepted" => accepted}, socket) do
    if accepted == "true" do
      {:noreply, push_event(socket, "ft_accept", %{})}
    else
      {:noreply, push_event(socket, "ft_reject", %{})}
    end
  end

  def handle_event("ft_accepted", _params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "transferring",
        percent: 0,
        speed: "0 B/s",
        eta: "--"
      })

    {:noreply, assign(socket, file_transfer: ft, diagram_collapsed: true)}
  end

  def handle_event("ft_rejected", _params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "rejected"
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_progress", params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "transferring",
        percent: params["percent"],
        speed: params["speed"],
        eta: params["eta"]
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_completed", params, socket) do
    Logger.info("P2P file completed: #{params["file_name"]}, token=#{socket.assigns.token}")

    P2P.close_session(socket.assigns.token, socket.assigns.user_id, "file_transfer_completed")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("p2p_close_tab", %{})}
  end

  def handle_event("ft_failed", params, socket) do
    Logger.warning("P2P file failed: #{params["reason"]}, token=#{socket.assigns.token}")

    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "failed",
        reason: params["reason"],
        can_retry: params["reason"] == "Integrity check failed"
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_cancelled", params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "cancelled",
        cancelled_by: params["cancelled_by"]
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_cancel", _params, socket) do
    {:noreply, push_event(socket, "ft_cancel", %{nickname: socket.assigns.nickname})}
  end

  def handle_event("ft_retry", _params, socket) do
    {:noreply, push_event(socket, "ft_retry", %{})}
  end

  def handle_event("ft_paused", _params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "paused"
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_resumed", _params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "resuming"
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_validation_error", params, socket) do
    ft = %{
      status: "validation_error",
      validation_error: params["error"]
    }

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_reset", _params, socket) do
    socket =
      socket
      |> assign(file_transfer: %{status: "ready"})
      |> maybe_push_ft_config()

    {:noreply, socket}
  end

  def handle_event("ft_queued", params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        queued_file: params["file_name"]
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  # --- Media Call Events ---

  def handle_event("media_call_started", %{"type" => type}, socket) do
    Logger.info("P2P call started: type=#{type}, token=#{socket.assigns.token}")

    call = %{
      status: "#{type}_active",
      type: type,
      duration: "00:00:00",
      quality_level: nil,
      quality_label: nil,
      peer_muted: false,
      peer_camera_off: false,
      upgrade_pending: false
    }

    {:noreply, assign(socket, call: call, diagram_collapsed: true, call_layout: "focus")}
  end

  def handle_event("media_call_ended", %{"reason" => reason}, socket) do
    Logger.info("P2P call ended: reason=#{reason}, token=#{socket.assigns.token}")

    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_call_ended", payload: %{reason: reason}}
    )

    P2P.close_session(socket.assigns.token, socket.assigns.user_id, "call_ended")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("p2p_close_tab", %{})}
  end

  def handle_event("media_error", %{"code" => code, "message" => message} = params, socket) do
    Logger.warning("P2P media error: #{message}, token=#{socket.assigns.token}")

    phase = Map.get(params, "phase")
    error_key = {phase, code, message}

    if socket.assigns[:last_media_error] == error_key do
      {:noreply, socket}
    else
      handle_new_media_error(socket, phase, error_key, message)
    end
  end

  def handle_event("media_mute_changed", %{"muted" => muted}, socket) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_mute", payload: %{muted: muted, from: socket.assigns.user_id}}
    )

    {:noreply, assign(socket, local_muted: muted)}
  end

  def handle_event("media_camera_changed", %{"off" => off}, socket) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_camera", payload: %{off: off, from: socket.assigns.user_id}}
    )

    {:noreply, assign(socket, local_camera_off: off)}
  end

  def handle_event("media_quality_update", %{"level" => level, "label" => label}, socket) do
    call = Map.merge(socket.assigns.call || %{}, %{quality_level: level, quality_label: label})
    {:noreply, assign(socket, call: call)}
  end

  def handle_event("media_stats", payload, socket) do
    {:noreply, assign(socket, stats: normalize_stats(payload))}
  end

  def handle_event("toggle_network_panel", _params, socket) do
    {:noreply, assign(socket, network_panel_collapsed: !socket.assigns.network_panel_collapsed)}
  end

  def handle_event("toggle_network_info", _params, socket) do
    {:noreply, assign(socket, network_info_open: !socket.assigns.network_info_open)}
  end

  def handle_event("media_duration_tick", %{"formatted" => formatted}, socket) do
    call = Map.merge(socket.assigns.call || %{}, %{duration: formatted})
    {:noreply, assign(socket, call: call)}
  end

  def handle_event("media_request_upgrade", _params, socket) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_upgrade_request", payload: %{from: socket.assigns.user_id}}
    )

    call = Map.merge(socket.assigns.call || %{}, %{upgrade_pending: true})
    {:noreply, assign(socket, call: call)}
  end

  def handle_event("media_respond_upgrade", %{"accepted" => accepted}, socket) do
    accepted_bool = accepted == "true" or accepted == true

    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{
        event: "media_upgrade_response",
        payload: %{accepted: accepted_bool, from: socket.assigns.user_id}
      }
    )

    {:noreply, apply_local_media_upgrade_response(socket, accepted_bool)}
  end

  def handle_event("media_select_preset", %{"preset" => preset}, socket) do
    {:noreply, push_event(socket, "media_set_preset", %{preset: preset})}
  end

  def handle_event("media_device_fallback", %{"message" => message}, socket) do
    msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: message,
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply, assign(socket, messages: socket.assigns.messages ++ [msg])}
  end

  def handle_event("media_devices_listed", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_diagram", _params, socket) do
    {:noreply, assign(socket, diagram_collapsed: !socket.assigns.diagram_collapsed)}
  end

  def handle_event("set_call_layout", %{"layout" => layout}, socket)
      when layout in @call_layouts do
    {:noreply, assign(socket, call_layout: layout)}
  end

  def handle_event("set_call_layout", _params, socket), do: {:noreply, socket}

  def handle_event("permission_result", %{"granted" => granted, "type" => type}, socket) do
    if granted do
      {:noreply,
       assign(socket,
         permission_granted: Map.put(socket.assigns[:permission_granted] || %{}, type, true)
       )}
    else
      error_msg = %{
        id: System.unique_integer([:positive]),
        sender_nick: dgettext("p2p", "System"),
        content: dgettext("p2p", "Permission denied for %{type}. Please try again.", type: type),
        type: "system",
        timestamp: DateTime.utc_now()
      }

      {:noreply, assign(socket, messages: socket.assigns.messages ++ [error_msg])}
    end
  end

  def handle_event("toggle_privacy_mode", _params, socket) do
    new_value = !socket.assigns.turn_only
    save_turn_only_preference(socket.assigns.nickname, new_value)
    {:noreply, assign(socket, turn_only: new_value)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    Logger.info("P2P LiveView terminated: token=#{socket.assigns[:token]}")

    if connected?(socket) and is_binary(socket.assigns[:token]) and
         !socket.assigns[:session_closed] do
      token = socket.assigns.token
      user_id = socket.assigns[:user_id]

      if user_id do
        try do
          P2P.close_session(token, user_id, "disconnected")
        rescue
          _ -> :ok
        end
      end
    end

    :ok
  end

  # --- Private Helpers ---

  defp mount_lobby(socket, token, nickname, user_id, db_session) do
    role = if user_id == db_session.creator_id, do: :creator, else: :peer
    Logger.info("P2P LiveView mounted: token=#{token}, user=#{nickname}, role=#{role}")

    local_info = SessionHelpers.parse_client_info(get_connect_params(socket))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "p2p:#{token}")
      P2P.join_session(token, user_id)

      Phoenix.PubSub.broadcast(
        @pubsub,
        "p2p:#{token}",
        %{event: "p2p_client_info", payload: %{from: user_id, info: local_info}}
      )
    end

    peer_nick = SessionHelpers.resolve_peer_nick(user_id, db_session)

    {messages, accepted_action_type, peer_online} = fetch_session_state(token, role)

    turn_only = load_turn_only_preference(nickname)
    turn_configured = P2P.turn_configured?()

    socket =
      assign(socket,
        session: db_session,
        token: token,
        nickname: nickname,
        user_id: user_id,
        peer_nick: peer_nick,
        peer_online: peer_online,
        role: role,
        messages: messages,
        action_request: nil,
        capabilities: %{webrtc: nil, getUserMedia: nil, dataChannel: nil},
        session_status: db_session.status,
        inactivity_warning: false,
        permission_granted: %{},
        webrtc_state: nil,
        retry_attempt: nil,
        webrtc_ready: false,
        webrtc_started: false,
        media_ready: false,
        media_started: false,
        file_transfer_ready: false,
        turn_warning_shown: false,
        file_transfer: init_file_transfer_on_mount(accepted_action_type, db_session.status),
        accepted_action_type: accepted_action_type,
        call: init_call_on_mount(accepted_action_type, db_session.status),
        stats: nil,
        network_panel_collapsed: false,
        network_info_open: false,
        signal_warning_shown: false,
        diagram_collapsed: true,
        call_layout: "focus",
        turn_only: turn_only,
        turn_configured: turn_configured,
        local_info: local_info,
        peer_info: %{},
        local_muted: false,
        local_camera_off: false,
        session_closed: false,
        session_ended_reason: nil,
        session_duration: nil
      )

    {:ok, socket}
  end

  defp fetch_session(token) do
    case P2P.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:redirect, nil}
    end
  end

  defp verify_not_terminal(session) do
    if Session.terminal?(session.status) do
      {:expired, session.closed_reason || session.status}
    else
      :ok
    end
  end

  defp maybe_auto_present(socket) do
    session = socket.assigns.session
    is_creator = socket.assigns.role == :creator
    non_generic = session.session_type != "generic"

    if is_creator and non_generic and socket.assigns.action_request == nil do
      action_type = session.session_type
      P2P.request_action(socket.assigns.token, socket.assigns.user_id, action_type)
    end

    {:noreply, socket}
  end

  defp fetch_session_state(token, role) do
    case P2P.session_info(token) do
      {:ok, state} ->
        action_type =
          if state.action_request && state.action_request.status == "accepted",
            do: state.action_request.action_type,
            else: nil

        peer_online =
          if role == :creator,
            do: state.peer_joined,
            else: state.creator_joined

        {state.messages, action_type, peer_online}

      _ ->
        {[], nil, false}
    end
  end

  defp init_file_transfer_on_mount(accepted_action_type, status) do
    if accepted_action_type == "file_transfer" && status in ["connecting", "active"],
      do: %{status: "ready"},
      else: nil
  end

  defp init_call_on_mount(accepted_action_type, status) do
    if accepted_action_type in ["audio_call", "video_call"] &&
         status in ["connecting", "active"] do
      %{
        status: "initializing",
        type: String.replace(accepted_action_type, "_call", ""),
        duration: "00:00:00",
        quality_level: nil,
        quality_label: nil,
        peer_muted: false,
        peer_camera_off: false,
        upgrade_pending: false
      }
    else
      nil
    end
  end

  defp sync_session_status(socket) do
    case P2P.session_info(socket.assigns.token) do
      {:ok, %{session: %{status: "active"}}} ->
        socket
        |> assign(session_status: "active", webrtc_state: "Connected")
        |> maybe_init_file_transfer()
        |> maybe_start_media_if_call()

      _ ->
        socket
    end
  end

  defp maybe_start_webrtc(
         %{assigns: %{session_status: "connecting", webrtc_ready: true, webrtc_started: false}} =
           socket
       ) do
    socket
    |> assign(webrtc_started: true)
    |> start_webrtc()
  end

  defp maybe_start_webrtc(socket), do: socket

  defp start_webrtc(socket) do
    socket = maybe_warn_turn_unavailable(socket)
    ice_servers = P2P.ice_servers(to_string(socket.assigns.user_id))
    turn_only = socket.assigns.turn_only && socket.assigns.turn_configured

    case socket.assigns.role do
      :creator ->
        push_event(socket, "p2p_start_offer", %{
          ice_servers: ice_servers,
          role: "initiator",
          turn_only: turn_only
        })

      :peer ->
        push_event(socket, "p2p_start_answer", %{
          ice_servers: ice_servers,
          turn_only: turn_only
        })
    end
  end

  defp maybe_warn_turn_unavailable(
         %{assigns: %{turn_only: true, turn_configured: false, turn_warning_shown: false}} =
           socket
       ) do
    warn_msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: dgettext("p2p", "Private mode requires a TURN server. Using direct connection."),
      type: "system",
      timestamp: DateTime.utc_now()
    }

    socket
    |> assign(messages: socket.assigns.messages ++ [warn_msg])
    |> assign(turn_warning_shown: true)
  end

  defp maybe_warn_turn_unavailable(socket), do: socket

  defp maybe_init_file_transfer(socket) do
    action_type =
      socket.assigns[:accepted_action_type] ||
        socket.assigns.session.session_type

    if action_type == "file_transfer" && socket.assigns.file_transfer == nil do
      socket
      |> assign(file_transfer: %{status: "ready"})
      |> assign(diagram_collapsed: true)
      |> maybe_push_ft_config()
    else
      socket
    end
  end

  defp maybe_push_ft_config(%{assigns: %{file_transfer: nil}} = socket), do: socket

  defp maybe_push_ft_config(%{assigns: %{file_transfer_ready: true}} = socket) do
    push_ft_config(socket)
  end

  defp maybe_push_ft_config(socket), do: socket

  defp push_ft_config(socket) do
    config = %{
      max_size_mb: Application.get_env(:retro_hex_chat, :file_transfer_max_size_mb, 500),
      blocked_extensions:
        Application.get_env(
          :retro_hex_chat,
          :file_transfer_blocked_extensions,
          ~w(.exe .bat .cmd .com .msi .scr .pif .vbs .vbe .js .jse .wsf .wsh .ps1 .reg)
        )
    }

    push_event(socket, "ft_config", config)
  end

  defp maybe_init_call(socket) do
    action_type =
      socket.assigns[:accepted_action_type] ||
        get_in(socket.assigns, [:action_request, :action_type]) ||
        socket.assigns.session.session_type

    if action_type in ["audio_call", "video_call"] && socket.assigns.call == nil do
      assign(socket,
        call: %{
          status: "initializing",
          type: String.replace(action_type, "_call", ""),
          duration: "00:00:00",
          quality_level: nil,
          quality_label: nil,
          peer_muted: false,
          peer_camera_off: false,
          upgrade_pending: false
        },
        diagram_collapsed: true,
        call_layout: "focus"
      )
    else
      socket
    end
  end

  defp maybe_start_media_if_call(
         %{assigns: %{session_status: "active", media_ready: true, media_started: false}} =
           socket
       ) do
    action_type =
      socket.assigns[:accepted_action_type] ||
        get_in(socket.assigns, [:action_request, :action_type])

    case action_type do
      "audio_call" ->
        socket
        |> assign(media_started: true)
        |> push_event("media_start_audio", %{})

      "video_call" ->
        socket
        |> assign(media_started: true)
        |> push_event("media_start_video", %{})

      _ ->
        socket
    end
  end

  defp maybe_start_media_if_call(socket), do: socket

  defp handle_new_media_error(socket, "upgrade", error_key, message) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{
        event: "media_upgrade_failed",
        payload: %{message: message, from: socket.assigns.user_id}
      }
    )

    {:noreply,
     socket
     |> assign(last_media_error: error_key)
     |> rollback_media_upgrade(message)}
  end

  defp handle_new_media_error(socket, _phase, error_key, message) do
    msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: message,
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> assign(call: nil, last_media_error: error_key)
     |> assign(messages: socket.assigns.messages ++ [msg])}
  end

  defp rollback_media_upgrade(socket, message) do
    call =
      if socket.assigns.call do
        Map.merge(socket.assigns.call, %{
          status: "audio_active",
          type: "audio",
          upgrade_pending: false,
          peer_camera_off: false
        })
      end

    socket =
      socket
      |> assign(call: call, local_camera_off: false, call_layout: "focus")
      |> push_event("media_upgrade_failed", %{})

    if message do
      msg = %{
        id: System.unique_integer([:positive]),
        sender_nick: dgettext("p2p", "System"),
        content: message,
        type: "system",
        timestamp: DateTime.utc_now()
      }

      assign(socket, messages: socket.assigns.messages ++ [msg])
    else
      socket
    end
  end

  defp apply_local_media_upgrade_response(%{assigns: %{call: nil}} = socket, _accepted?) do
    socket
  end

  defp apply_local_media_upgrade_response(socket, true) do
    call =
      Map.merge(socket.assigns.call, %{
        status: "video_active",
        type: "video",
        upgrade_pending: false
      })

    socket
    |> assign(call: call)
    |> push_event("media_upgrade_accepted", %{})
  end

  defp apply_local_media_upgrade_response(socket, false) do
    call = Map.merge(socket.assigns.call, %{upgrade_pending: false})

    msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: dgettext("p2p", "Video request declined."),
      type: "system",
      timestamp: DateTime.utc_now()
    }

    socket
    |> assign(call: call)
    |> assign(messages: socket.assigns.messages ++ [msg])
    |> push_event("media_upgrade_rejected", %{})
  end

  @spec system_message(String.t()) :: map()
  defp system_message(content) do
    %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("p2p", "System"),
      content: content,
      type: "system",
      timestamp: DateTime.utc_now()
    }
  end

  @spec connection_failure_message(String.t()) :: String.t()
  defp connection_failure_message("max_retries_exhausted") do
    dgettext(
      "p2p",
      "Could not establish the P2P connection after several attempts. Check your network and try again."
    )
  end

  defp connection_failure_message(reason)
       when reason in ["offer_failed", "answer_failed", "retry_failed"] do
    dgettext("p2p", "Failed to negotiate the P2P connection. The call could not be established.")
  end

  defp connection_failure_message(_reason) do
    dgettext("p2p", "The P2P connection failed.")
  end

  @spec maybe_warn_signal_rate_limited(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp maybe_warn_signal_rate_limited(%{assigns: %{signal_warning_shown: true}} = socket),
    do: socket

  defp maybe_warn_signal_rate_limited(socket) do
    msg =
      system_message(
        dgettext(
          "p2p",
          "Connection setup is being throttled (too many signaling messages). Connecting may take longer."
        )
      )

    socket
    |> assign(signal_warning_shown: true)
    |> assign(messages: socket.assigns.messages ++ [msg])
  end

  @spec normalize_stats(map()) :: map()
  defp normalize_stats(payload) do
    %{
      level: payload["level"],
      mos: payload["mos"],
      rtt_ms: payload["rtt_ms"],
      jitter_ms: payload["jitter_ms"],
      loss_pct: payload["loss_pct"],
      inbound_kbps: payload["inbound_kbps"],
      outbound_kbps: payload["outbound_kbps"],
      available_kbps: payload["available_kbps"],
      fps: payload["fps"],
      frame_width: payload["frame_width"],
      frame_height: payload["frame_height"],
      freeze_count: payload["freeze_count"],
      limitation: payload["limitation"],
      has_video: payload["has_video"]
    }
  end

  defp action_response_message(action_type, true) do
    dgettext("p2p", "%{action} request accepted.", action: action_label(action_type))
  end

  defp action_response_message(action_type, _accepted) do
    dgettext("p2p", "%{action} request declined.", action: action_label(action_type))
  end

  defp action_label("audio_call"), do: dgettext("p2p", "Audio call")
  defp action_label("video_call"), do: dgettext("p2p", "Video call")
  defp action_label("file_transfer"), do: dgettext("p2p", "File transfer")
  defp action_label(action), do: to_string(action)

  defp expired_reason_label("user_closed"), do: dgettext("p2p", "Session closed by user.")
  defp expired_reason_label("rejected"), do: dgettext("p2p", "P2P invite was rejected.")
  defp expired_reason_label("tab_closed"), do: dgettext("p2p", "Session closed (disconnected).")
  defp expired_reason_label("disconnected"), do: dgettext("p2p", "Session closed (disconnected).")
  defp expired_reason_label("expired"), do: dgettext("p2p", "Session expired due to inactivity.")

  defp expired_reason_label("failed"),
    do: dgettext("p2p", "Session closed due to connection failure.")

  defp expired_reason_label("call_ended"), do: dgettext("p2p", "Call ended.")

  defp expired_reason_label("file_transfer_completed"),
    do: dgettext("p2p", "File transfer completed.")

  defp expired_reason_label("user_blocked"),
    do: dgettext("p2p", "Session closed because a user was ignored.")

  defp expired_reason_label(_reason), do: dgettext("p2p", "P2P session ended.")

  @spec compute_session_duration(Phoenix.LiveView.Socket.t()) :: integer()
  defp compute_session_duration(socket) do
    token = socket.assigns[:token]
    session = socket.assigns[:session]

    case RetroHexChat.P2P.get_session(token) do
      {:ok, fresh} when is_integer(fresh.duration_seconds) -> fresh.duration_seconds
      _ -> DateTime.diff(DateTime.utc_now(), session.inserted_at)
    end
  end

  defp load_turn_only_preference(nickname) do
    case RetroHexChat.Repo.get(UserPreference, nickname) do
      nil -> false
      pref -> get_in(pref.display_settings, ["p2p_settings", "turn_only"]) == true
    end
  end

  defp save_turn_only_preference(nickname, turn_only) do
    case RetroHexChat.Repo.get(UserPreference, nickname) do
      nil ->
        %UserPreference{}
        |> UserPreference.changeset(%{
          owner_nickname: nickname,
          display_settings: %{"p2p_settings" => %{"turn_only" => turn_only}}
        })
        |> RetroHexChat.Repo.insert()

      pref ->
        current = pref.display_settings || %{}
        p2p = Map.get(current, "p2p_settings", %{})
        updated = Map.put(current, "p2p_settings", Map.put(p2p, "turn_only", turn_only))

        pref
        |> UserPreference.changeset(%{display_settings: updated})
        |> RetroHexChat.Repo.update()
    end
  end
end
