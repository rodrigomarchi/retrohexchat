defmodule RetroHexChatWeb.P2PSessionLive do
  @moduledoc """
  LiveView for the P2P session lobby.
  Provides ephemeral chat, peer presence, and bilateral consent for actions.
  """

  use RetroHexChatWeb, :live_view

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
    user_id = socket.assigns.user_id
    role = socket.assigns.role

    ice_servers = P2P.ice_servers(to_string(user_id))

    socket = assign(socket, session_status: "connecting")

    socket =
      case role do
        :creator ->
          push_event(socket, "p2p_start_offer", %{ice_servers: ice_servers, role: "initiator"})

        :peer ->
          push_event(socket, "p2p_start_answer", %{ice_servers: ice_servers})
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
      {:noreply, assign(socket, session_status: status)}
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
    {:noreply,
     assign(socket, action_request: Map.merge(socket.assigns.action_request || %{}, response))}
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
      {:noreply, push_event(socket, "p2p_request_permission", %{type: permission_type(socket)})}
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
    case P2P.transition_status(socket.assigns.token, :active) do
      :ok ->
        {:noreply, assign(socket, session_status: "active")}

      {:error, _reason} ->
        # Ignore — session not in a state that allows this transition
        {:noreply, socket}
    end
  end

  def handle_event("p2p_failed", %{"reason" => reason}, socket) do
    require Logger
    Logger.warning("P2P connection failed: #{reason}, token: #{socket.assigns.token}")

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

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
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
    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "p2p:#{token}")
      P2P.join_session(token, user_id)
    end

    peer_nick = resolve_peer_nick(user_id, db_session)
    role = if user_id == db_session.creator_id, do: :creator, else: :peer

    # Get existing messages from GenServer state
    messages =
      case P2P.session_info(token) do
        {:ok, state} -> state.messages
        _ -> []
      end

    socket =
      assign(socket,
        session: db_session,
        token: token,
        nickname: nickname,
        user_id: user_id,
        peer_nick: peer_nick,
        peer_online: false,
        role: role,
        messages: messages,
        action_request: nil,
        capabilities: %{webrtc: nil, getUserMedia: nil, dataChannel: nil},
        session_status: db_session.status,
        inactivity_warning: false,
        permission_granted: %{},
        webrtc_state: nil,
        retry_attempt: nil
      )

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

  defp permission_type(socket) do
    case socket.assigns[:action_request] do
      %{action_type: "audio_call"} -> "microphone"
      %{action_type: "video_call"} -> "camera"
      _ -> "microphone"
    end
  end

  defp webrtc_state_label("connecting", _attempt), do: "Conectando..."
  defp webrtc_state_label("connected", _attempt), do: "Conectado"
  defp webrtc_state_label("disconnected", _attempt), do: "Reconectando..."
  defp webrtc_state_label("failed", _attempt), do: "Falha na conexao"
  defp webrtc_state_label(_state, _attempt), do: nil

  defp close_reason_message("user_closed"), do: "Sessao P2P encerrada."
  defp close_reason_message("rejected"), do: "Convite P2P recusado."
  defp close_reason_message("tab_closed"), do: "Peer desconectou."
  defp close_reason_message("disconnected"), do: "Peer desconectou."
  defp close_reason_message(_reason), do: "Sessao P2P encerrada."
end
