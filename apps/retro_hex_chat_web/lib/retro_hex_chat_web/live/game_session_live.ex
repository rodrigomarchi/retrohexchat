defmodule RetroHexChatWeb.GameSessionLive do
  @moduledoc """
  LiveView for the game session lobby and gameplay.
  Provides game selection, bilateral consent, WebRTC signaling for DataChannel,
  and the game canvas container.
  """

  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Games
  alias RetroHexChat.Games.Schema.GameSession
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.Components.{GameCanvas, GameLobby}

  @pubsub RetroHexChat.PubSub

  @impl true
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- verify_nickname(socket, nickname),
         {:ok, user_id} <- resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- verify_participant(user_id, db_session),
         :ok <- verify_not_terminal(db_session) do
      mount_game_lobby(socket, token, nickname, user_id, db_session)
    else
      {:expired, reason, metadata} ->
        {:ok,
         assign(socket,
           expired: true,
           expired_reason: expired_reason_label(reason),
           game_result: metadata["result"]
         )}

      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, push_navigate(socket, to: ~p"/chat")}
    end
  end

  # --- Render ---

  @impl true
  def render(%{expired: true} = assigns) do
    ~H"""
    <div class="app-container">
      <RetroHexChatWeb.Components.AppHeader.app_header>
        <:panels>
          <div class="toolbar toolbar--skeleton">
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
          </div>
          <div class="status-bar status-bar--skeleton">
            <p class="status-bar-field">&nbsp;</p>
          </div>
        </:panels>
      </RetroHexChatWeb.Components.AppHeader.app_header>
      <div class="game-lobby">
        <GameLobby.game_expired reason={@expired_reason} game_result={@game_result} />
      </div>
    </div>
    """
  end

  def render(%{session_status: "playing"} = assigns) do
    ~H"""
    <div id="game-session" class="app-container" phx-hook="GameSessionHook">
      <RetroHexChatWeb.Components.AppHeader.app_header>
        <:panels>
          <div class="toolbar toolbar--skeleton">
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
          </div>
          <div class="status-bar status-bar--skeleton">
            <p class="status-bar-field">&nbsp;</p>
          </div>
        </:panels>
      </RetroHexChatWeb.Components.AppHeader.app_header>
      <div id="game-webrtc" phx-hook="GameWebRTCHook"></div>
      <GameCanvas.game_canvas
        nickname={@nickname}
        peer_nick={@peer_nick}
        game_id={@game_id}
        game_name={@game_name}
        is_host={@role == :creator}
      />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="game-session" class="app-container" phx-hook="GameSessionHook">
      <RetroHexChatWeb.Components.AppHeader.app_header>
        <:panels>
          <div class="toolbar toolbar--skeleton">
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
          </div>
          <div class="status-bar status-bar--skeleton">
            <p class="status-bar-field">&nbsp;</p>
          </div>
        </:panels>
      </RetroHexChatWeb.Components.AppHeader.app_header>
      <GameLobby.game_lobby
        nickname={@nickname}
        peer_nick={@peer_nick}
        peer_online={@peer_online}
        messages={@messages}
        games={@games}
        game_request={@game_request}
        session_status={@session_status}
        inactivity_warning={@inactivity_warning}
      />
    </div>
    """
  end

  # --- PubSub Handlers ---

  @impl true
  def handle_info(%{event: "game_peer_joined", payload: %{user_id: uid}}, socket) do
    if uid != socket.assigns.user_id do
      {:noreply, assign(socket, peer_online: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "game_status_changed", payload: %{status: "lobby"}}, socket) do
    {:noreply, assign(socket, session_status: "lobby")}
  end

  def handle_info(
        %{event: "game_status_changed", payload: %{status: "playing", game_id: game_id}},
        socket
      ) do
    game_name =
      case Games.get_game(game_id) do
        {:ok, game} -> game.name
        _ -> game_id
      end

    socket =
      socket
      |> assign(
        session_status: "playing",
        game_id: game_id,
        game_name: game_name
      )
      |> start_webrtc()

    {:noreply, socket}
  end

  def handle_info(%{event: "game_status_changed", payload: %{status: status}}, socket) do
    if GameSession.terminal?(status) do
      socket =
        socket
        |> push_event("game_end", %{})
        |> assign(session_closed: true)
        |> push_event("game_close_tab", %{})

      {:noreply, socket}
    else
      {:noreply, assign(socket, session_status: status)}
    end
  end

  def handle_info(%{event: "game_lobby_message", payload: msg}, socket) do
    messages = socket.assigns.messages ++ [msg]
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info(%{event: "game_select_request", payload: request}, socket) do
    {:noreply, assign(socket, game_request: request)}
  end

  def handle_info(%{event: "game_select_response", payload: response}, socket) do
    if response[:accepted] do
      # Transition handled by session_server broadcast of game_status_changed
      {:noreply, assign(socket, game_request: nil)}
    else
      {:noreply, assign(socket, game_request: nil)}
    end
  end

  def handle_info(%{event: "game_select_expired"}, socket) do
    expired_msg = %{
      id: System.unique_integer([:positive]),
      sender_nick: "System",
      content: "Game selection expired.",
      type: "system",
      timestamp: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> assign(game_request: nil)
     |> assign(messages: socket.assigns.messages ++ [expired_msg])}
  end

  def handle_info(%{event: "game_session_closed", payload: %{reason: _reason}}, socket) do
    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("game_close_tab", %{})}
  end

  def handle_info(
        %{event: "game_inactivity_warning", payload: %{expires_in_seconds: _secs}},
        socket
      ) do
    {:noreply, assign(socket, inactivity_warning: true)}
  end

  # WebRTC signaling relay
  def handle_info(
        %{event: "game_signal", payload: %{from: from_id} = payload},
        socket
      ) do
    if from_id != socket.assigns.user_id do
      {:noreply, push_event(socket, "game_signal", payload)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Client Event Handlers ---

  @impl true
  def handle_event("send_lobby_message", %{"content" => content}, socket) do
    Games.send_lobby_message(socket.assigns.token, socket.assigns.user_id, content)
    {:noreply, socket}
  end

  def handle_event("select_game", %{"game_id" => game_id}, socket) do
    Games.select_game(socket.assigns.token, socket.assigns.user_id, game_id)
    {:noreply, socket}
  end

  def handle_event("respond_game", %{"accepted" => accepted}, socket) do
    accepted_bool = accepted == "true" or accepted == true
    Games.respond_game(socket.assigns.token, socket.assigns.user_id, accepted_bool)
    {:noreply, socket}
  end

  def handle_event("close_session", _params, socket) do
    Games.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("game_close_tab", %{})}
  end

  def handle_event("end_game", _params, socket) do
    Games.close_session(socket.assigns.token, socket.assigns.user_id, "game_ended")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("game_close_tab", %{})}
  end

  # WebRTC signaling events
  def handle_event("game_signal", params, socket) do
    rate_limiter = SignalingRateLimit.configured_module()

    with :ok <- rate_limiter.check_signal_rate(socket.assigns.token, socket.assigns.user_id),
         {:ok, validated} <- RetroHexChat.P2P.validate_signal(params) do
      payload = Map.put(validated, :from, socket.assigns.user_id)

      Phoenix.PubSub.broadcast(
        @pubsub,
        "game:#{socket.assigns.token}",
        %{event: "game_signal", payload: payload}
      )

      {:noreply, socket}
    else
      {:error, :rate_limited} -> {:noreply, socket}
      {:error, :invalid_signal} -> {:noreply, socket}
    end
  end

  def handle_event("game_result", %{"score" => score, "winner" => winner}, socket) do
    result = %{"score" => score, "winner" => winner}
    Games.finish_game(socket.assigns.token, socket.assigns.user_id, result)
    {:noreply, socket}
  end

  def handle_event("game_connected", _params, socket) do
    Logger.info("Game WebRTC connected: token=#{socket.assigns.token}")

    socket =
      socket
      |> assign(webrtc_state: "Connected")
      |> push_event("game_start", %{
        game_id: socket.assigns.game_id,
        is_host: socket.assigns.role == :creator
      })

    {:noreply, socket}
  end

  def handle_event("game_failed", %{"reason" => reason}, socket) do
    Logger.warning("Game WebRTC failed: #{reason}, token=#{socket.assigns.token}")
    {:noreply, assign(socket, webrtc_state: "failed")}
  end

  def handle_event("game_rtc_state", %{"state" => state}, socket) do
    {:noreply, assign(socket, webrtc_state: webrtc_state_label(state))}
  end

  def handle_event("game_leave", _params, socket) do
    unless socket.assigns[:session_closed] do
      Games.close_session(socket.assigns.token, socket.assigns.user_id, "tab_closed")
    end

    {:noreply, assign(socket, session_closed: true)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if connected?(socket) and socket.assigns[:token] and !socket.assigns[:session_closed] do
      token = socket.assigns.token
      user_id = socket.assigns[:user_id]

      if user_id do
        try do
          Games.close_session(token, user_id, "disconnected")
        rescue
          _ -> :ok
        end
      end
    end

    :ok
  end

  # --- Private Helpers ---

  defp mount_game_lobby(socket, token, nickname, user_id, db_session) do
    role = if user_id == db_session.creator_id, do: :creator, else: :peer

    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "game:#{token}")
      Games.join_session(token, user_id)
    end

    peer_nick = resolve_peer_nick(user_id, db_session)
    {messages, peer_online} = fetch_session_state(token, role)

    games = Games.list_games()

    # If already playing, resolve game info
    {game_id, game_name} = resolve_game_info(db_session)

    socket =
      assign(socket,
        token: token,
        nickname: nickname,
        user_id: user_id,
        peer_nick: peer_nick,
        peer_online: peer_online,
        role: role,
        messages: messages,
        games: games,
        game_request: nil,
        session_status: db_session.status,
        inactivity_warning: false,
        webrtc_state: nil,
        game_id: game_id,
        game_name: game_name,
        session_closed: false
      )

    {:ok, socket}
  end

  defp verify_nickname(socket, nil) do
    {:redirect, push_navigate(socket, to: ~p"/connect")}
  end

  defp verify_nickname(socket, _nickname), do: {:ok, socket}

  defp resolve_user_id(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:redirect, nil}
      nick -> {:ok, nick.id}
    end
  end

  defp fetch_session(token) do
    case Games.get_session(token) do
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
    if GameSession.terminal?(session.status) do
      {:expired, session.closed_reason || session.status, session.metadata || %{}}
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

  defp fetch_session_state(token, role) do
    case Games.session_info(token) do
      {:ok, state} ->
        peer_online =
          if role == :creator,
            do: state.peer_joined,
            else: state.creator_joined

        {state.messages, peer_online}

      _ ->
        {[], false}
    end
  end

  defp resolve_game_info(%{status: "playing", game_id: game_id}) when is_binary(game_id) do
    game_name =
      case Games.get_game(game_id) do
        {:ok, game} -> game.name
        _ -> game_id
      end

    {game_id, game_name}
  end

  defp resolve_game_info(_session), do: {nil, nil}

  defp start_webrtc(socket) do
    user_id = socket.assigns.user_id
    role = socket.assigns.role
    ice_servers = Games.ice_servers(to_string(user_id))

    case role do
      :creator ->
        push_event(socket, "game_start_offer", %{
          ice_servers: ice_servers,
          role: "initiator",
          turn_only: false
        })

      :peer ->
        push_event(socket, "game_start_answer", %{
          ice_servers: ice_servers,
          turn_only: false
        })
    end
  end

  defp webrtc_state_label("connecting"), do: "Connecting..."
  defp webrtc_state_label("connected"), do: "Connected"
  defp webrtc_state_label("disconnected"), do: "Reconnecting..."
  defp webrtc_state_label("failed"), do: "Connection failed"
  defp webrtc_state_label(_state), do: nil

  defp expired_reason_label("user_closed"), do: "Session closed by user."
  defp expired_reason_label("game_ended"), do: "Game ended."
  defp expired_reason_label("rejected"), do: "Game invite was rejected."
  defp expired_reason_label("tab_closed"), do: "Session closed (disconnected)."
  defp expired_reason_label("disconnected"), do: "Session closed (disconnected)."
  defp expired_reason_label("expired"), do: "Session expired due to inactivity."
  defp expired_reason_label("pending_timeout"), do: "Session expired — peer did not join."
  defp expired_reason_label("lobby_inactivity"), do: "Session expired due to inactivity."
  defp expired_reason_label(_reason), do: "Game session ended."
end
