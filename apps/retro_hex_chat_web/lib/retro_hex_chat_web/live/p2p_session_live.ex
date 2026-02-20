defmodule RetroHexChatWeb.P2PSessionLive do
  @moduledoc """
  LiveView for the P2P session lobby.
  Provides ephemeral chat, peer presence, and bilateral consent for actions.
  """

  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.Schema.Session
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.Components.P2pLobby

  @pubsub RetroHexChat.PubSub

  @impl true
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- verify_nickname(socket, nickname),
         {:ok, user_id} <- resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- verify_participant(user_id, db_session),
         :ok <- verify_not_terminal(db_session) do
      mount_lobby(socket, token, nickname, user_id, db_session)
    else
      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, push_navigate(socket, to: ~p"/chat")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="p2p-session" class="p2p-session" phx-hook="P2PSessionHook">
      <div id="p2p-capabilities" phx-hook="P2PCapabilityHook"></div>
      <div id="p2p-webrtc" phx-hook="WebRTCHook"></div>
      <P2pLobby.p2p_lobby
        session={@session}
        nickname={@nickname}
        peer_nick={@peer_nick}
        peer_online={@peer_online}
        messages={@messages}
        action_request={@action_request}
        capabilities={@capabilities}
        session_status={@session_status}
        inactivity_warning={@inactivity_warning}
        role={@role}
        webrtc_state={@webrtc_state}
        retry_attempt={@retry_attempt}
        file_transfer={@file_transfer}
        call={@call}
        turn_only={@turn_only}
        turn_configured={@turn_configured}
      />
    </div>
    """
  end

  # --- PubSub Handlers ---

  @impl true
  def handle_info(
        %{event: "p2p_status_changed", payload: %{status: "connecting"}},
        socket
      ) do
    Logger.info("P2P connecting: token=#{socket.assigns.token}, role=#{socket.assigns.role}")

    user_id = socket.assigns.user_id
    role = socket.assigns.role
    turn_only = socket.assigns.turn_only

    ice_servers = P2P.ice_servers(to_string(user_id))

    # If turn_only but TURN not configured, warn and fall back
    {effective_turn_only, socket} =
      if turn_only and not P2P.turn_configured?() do
        warn_msg = %{
          id: System.unique_integer([:positive]),
          sender_nick: "Sistema",
          content: "Modo privado requer servidor TURN. Usando conexao direta.",
          type: "system",
          timestamp: DateTime.utc_now()
        }

        socket = assign(socket, messages: socket.assigns.messages ++ [warn_msg])
        {false, socket}
      else
        {turn_only, socket}
      end

    socket = assign(socket, session_status: "connecting", action_request: nil)

    socket =
      case role do
        :creator ->
          push_event(socket, "p2p_start_offer", %{
            ice_servers: ice_servers,
            role: "initiator",
            turn_only: effective_turn_only
          })

        :peer ->
          push_event(socket, "p2p_start_answer", %{
            ice_servers: ice_servers,
            turn_only: effective_turn_only
          })
      end

    {:noreply, socket}
  end

  def handle_info(%{event: "p2p_status_changed", payload: %{status: status}}, socket) do
    if Session.terminal?(status) do
      {:noreply,
       socket
       |> put_flash(:info, "Sessao P2P encerrada.")
       |> push_navigate(to: ~p"/chat")}
    else
      socket = assign(socket, session_status: status)

      socket =
        if status == "active" do
          socket
          |> assign(webrtc_state: "Conectado")
          |> maybe_init_file_transfer()
          |> start_media_if_call()
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
        %{event: "p2p_action_request", payload: %{requester_id: req_id} = request},
        socket
      ) do
    if req_id != socket.assigns.user_id do
      {:noreply, assign(socket, action_request: request)}
    else
      {:noreply, assign(socket, action_request: request)}
    end
  end

  def handle_info(%{event: "p2p_action_response", payload: response}, socket) do
    action_request =
      (socket.assigns.action_request || %{})
      |> Map.merge(response)
      |> Map.put(:status, if(response[:accepted], do: "accepted", else: "rejected"))

    socket = assign(socket, action_request: action_request)

    # Store accepted action type for later use (e.g., initializing file transfer UI)
    socket =
      if response[:accepted] do
        assign(socket, accepted_action_type: response[:action_type])
      else
        socket
      end

    # If accepted and this is the requester, init call UI (but don't start media yet —
    # that happens on p2p_connected when WebRTC is ready and MediaHook exists)
    if response[:accepted] && response[:responder_id] != socket.assigns.user_id do
      {:noreply, maybe_init_call(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "p2p_action_expired"}, socket) do
    expired_msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: "Sistema",
      content: "Pedido expirou.",
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> assign(action_request: nil)
     |> assign(messages: socket.assigns.messages ++ [expired_msg])}
  end

  def handle_info(%{event: "p2p_session_closed", payload: %{reason: reason}}, socket) do
    msg = close_reason_message(reason)

    {:noreply,
     socket
     |> put_flash(:info, msg)
     |> push_navigate(to: ~p"/chat")}
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
    # Only forward signals from the other peer
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
        sender_nick: "Sistema",
        content: "Chamada encerrada: #{reason}",
        type: "system",
        timestamp: DateTime.utc_now()
      }

      {:noreply,
       socket
       |> assign(call: nil)
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
          sender_nick: "Sistema",
          content: "Pedido de video recusado.",
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

  def handle_info(%{event: "p2p_peer_joined", payload: %{user_id: uid}}, socket) do
    if uid != socket.assigns.user_id do
      socket = assign(socket, peer_online: true)
      maybe_auto_present(socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Client Event Handlers ---

  @impl true
  def handle_event("send_lobby_message", %{"content" => content}, socket) do
    P2P.send_lobby_message(socket.assigns.token, socket.assigns.user_id, content)
    {:noreply, socket}
  end

  def handle_event("request_action", %{"action_type" => type}, socket) do
    P2P.request_action(socket.assigns.token, socket.assigns.user_id, type)
    {:noreply, socket}
  end

  def handle_event("respond_action", %{"accepted" => accepted}, socket) do
    accepted_bool = accepted == "true" or accepted == true
    P2P.respond_action(socket.assigns.token, socket.assigns.user_id, accepted_bool)

    if accepted_bool do
      {:noreply, maybe_init_call(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_session", _params, socket) do
    P2P.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")

    {:noreply,
     socket
     |> put_flash(:info, "Sessao P2P encerrada.")
     |> push_navigate(to: ~p"/chat")}
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
      {:error, :rate_limited} -> {:noreply, socket}
      {:error, :invalid_signal} -> {:noreply, socket}
    end
  end

  def handle_event("p2p_connected", _params, socket) do
    Logger.info("P2P connected: token=#{socket.assigns.token}")

    case P2P.transition_status(socket.assigns.token, :active) do
      :ok ->
        socket =
          socket
          |> assign(session_status: "active", webrtc_state: "Conectado")
          |> maybe_init_file_transfer()
          |> start_media_if_call()

        {:noreply, socket}

      {:error, _reason} ->
        # Transition may have been done by other peer — check actual state
        socket = sync_session_status(socket)
        {:noreply, socket}
    end
  end

  def handle_event("p2p_failed", %{"reason" => reason}, socket) do
    Logger.warning("P2P connection failed: #{reason}, token=#{socket.assigns.token}")

    case P2P.transition_status(socket.assigns.token, :failed) do
      :ok ->
        {:noreply, assign(socket, session_status: "failed", webrtc_state: "failed")}

      {:error, _reason} ->
        {:noreply, socket}
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
    label = webrtc_state_label(state, socket.assigns[:retry_attempt])
    {:noreply, assign(socket, webrtc_state: label)}
  end

  def handle_event("p2p_leave", _params, socket) do
    P2P.close_session(socket.assigns.token, socket.assigns.user_id, "tab_closed")
    {:noreply, socket}
  end

  # --- File Transfer Events ---

  def handle_event("ft_offer_sent", params, socket) do
    Logger.info(
      "P2P file offer: #{params["fileName"]} (#{params["formattedSize"]}), token=#{socket.assigns.token}"
    )

    ft = %{
      status: "offering",
      file_name: params["fileName"],
      file_size: params["fileSize"],
      formatted_size: params["formattedSize"],
      sender_nick: socket.assigns.nickname
    }

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_offer_received", params, socket) do
    ft = %{
      status: "offer_received",
      file_name: params["fileName"],
      file_size: params["fileSize"],
      formatted_size: params["formattedSize"],
      sender_nick: socket.assigns.peer_nick
    }

    {:noreply, assign(socket, file_transfer: ft)}
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

    {:noreply, assign(socket, file_transfer: ft)}
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
    Logger.info("P2P file completed: #{params["fileName"]}, token=#{socket.assigns.token}")

    ft = %{
      status: "completed",
      file_name: params["fileName"]
    }

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_failed", params, socket) do
    Logger.warning("P2P file failed: #{params["reason"]}, token=#{socket.assigns.token}")

    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "failed",
        reason: params["reason"],
        can_retry: params["reason"] == "Verificacao de integridade falhou"
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_cancelled", params, socket) do
    ft = %{
      status: "cancelled",
      cancelled_by: params["cancelledBy"]
    }

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
      |> push_ft_config()

    {:noreply, socket}
  end

  def handle_event("ft_queued", params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        queued_file: params["fileName"]
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

    {:noreply, assign(socket, call: call)}
  end

  def handle_event("media_call_ended", %{"reason" => reason}, socket) do
    Logger.info("P2P call ended: reason=#{reason}, token=#{socket.assigns.token}")

    msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: "Sistema",
      content: "Chamada encerrada: #{reason}",
      type: "system",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_call_ended", payload: %{reason: reason}}
    )

    {:noreply,
     socket
     |> assign(call: nil)
     |> assign(messages: socket.assigns.messages ++ [msg])}
  end

  def handle_event("media_error", %{"code" => _code, "message" => message}, socket) do
    Logger.warning("P2P media error: #{message}, token=#{socket.assigns.token}")

    msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: "Sistema",
      content: message,
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> assign(call: nil)
     |> assign(messages: socket.assigns.messages ++ [msg])}
  end

  def handle_event("media_mute_changed", %{"muted" => muted}, socket) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_mute", payload: %{muted: muted, from: socket.assigns.user_id}}
    )

    {:noreply, socket}
  end

  def handle_event("media_camera_changed", %{"off" => off}, socket) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "p2p:#{socket.assigns.token}",
      %{event: "media_camera", payload: %{off: off, from: socket.assigns.user_id}}
    )

    {:noreply, socket}
  end

  def handle_event("media_quality_update", %{"level" => level, "label" => label}, socket) do
    call = Map.merge(socket.assigns.call || %{}, %{quality_level: level, quality_label: label})
    {:noreply, assign(socket, call: call)}
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

    {:noreply, socket}
  end

  def handle_event("media_select_preset", %{"preset" => preset}, socket) do
    {:noreply, push_event(socket, "media_set_preset", %{preset: preset})}
  end

  def handle_event("media_device_fallback", %{"message" => message}, socket) do
    msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: "Sistema",
      content: message,
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply, assign(socket, messages: socket.assigns.messages ++ [msg])}
  end

  def handle_event("media_devices_listed", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("permission_result", %{"granted" => granted, "type" => type}, socket) do
    if granted do
      {:noreply,
       assign(socket,
         permission_granted: Map.put(socket.assigns[:permission_granted] || %{}, type, true)
       )}
    else
      error_msg = %{
        id: System.unique_integer([:positive]),
        sender_nick: "Sistema",
        content: "Permissao negada para #{type}. Tente novamente.",
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

    if connected?(socket) and socket.assigns[:token] do
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

    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "p2p:#{token}")
      P2P.join_session(token, user_id)
    end

    peer_nick = resolve_peer_nick(user_id, db_session)

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
        file_transfer: init_file_transfer_on_mount(accepted_action_type, db_session.status),
        accepted_action_type: accepted_action_type,
        call: init_call_on_mount(accepted_action_type, db_session.status),
        turn_only: turn_only,
        turn_configured: turn_configured
      )

    socket =
      if connected?(socket) && socket.assigns.file_transfer do
        push_ft_config(socket)
      else
        socket
      end

    {:ok, socket}
  end

  defp verify_nickname(socket, nil) do
    {:redirect, push_navigate(socket, to: ~p"/")}
  end

  defp verify_nickname(socket, _nickname), do: {:ok, socket}

  defp resolve_user_id(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:redirect, nil}
      nick -> {:ok, nick.id}
    end
  end

  defp fetch_session(token) do
    case P2P.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:redirect, nil}
    end
  end

  defp verify_participant(user_id, session) do
    if user_id == session.creator_id or user_id == session.peer_id do
      :ok
    else
      {:redirect, nil}
    end
  end

  defp verify_not_terminal(session) do
    if Session.terminal?(session.status) do
      {:redirect, nil}
    else
      :ok
    end
  end

  defp resolve_peer_nick(user_id, session) do
    peer_id = if user_id == session.creator_id, do: session.peer_id, else: session.creator_id

    case RetroHexChat.Repo.get(RegisteredNick, peer_id) do
      nil -> "unknown"
      nick -> nick.nickname
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
        |> assign(session_status: "active", webrtc_state: "Conectado")
        |> maybe_init_file_transfer()
        |> start_media_if_call()

      _ ->
        socket
    end
  end

  defp maybe_init_file_transfer(socket) do
    action_type =
      socket.assigns[:accepted_action_type] ||
        socket.assigns.session.session_type

    if action_type == "file_transfer" && socket.assigns.file_transfer == nil do
      socket
      |> assign(file_transfer: %{status: "ready"})
      |> push_ft_config()
    else
      socket
    end
  end

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
        }
      )
    else
      socket
    end
  end

  defp start_media_if_call(socket) do
    action_type =
      socket.assigns[:accepted_action_type] ||
        get_in(socket.assigns, [:action_request, :action_type])

    case action_type do
      "audio_call" -> push_event(socket, "media_start_audio", %{})
      "video_call" -> push_event(socket, "media_start_video", %{})
      _ -> socket
    end
  end

  defp webrtc_state_label("connecting", _attempt), do: "Connecting..."
  defp webrtc_state_label("connected", _attempt), do: "Connected"
  defp webrtc_state_label("disconnected", _attempt), do: "Reconnecting..."
  defp webrtc_state_label("failed", _attempt), do: "Connection failed"
  defp webrtc_state_label(_state, _attempt), do: nil

  defp close_reason_message("user_closed"), do: "P2P session closed."
  defp close_reason_message("rejected"), do: "P2P invite rejected."
  defp close_reason_message("tab_closed"), do: "Peer disconnected."
  defp close_reason_message("disconnected"), do: "Peer desconectou."
  defp close_reason_message(_reason), do: "Sessao P2P encerrada."

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
