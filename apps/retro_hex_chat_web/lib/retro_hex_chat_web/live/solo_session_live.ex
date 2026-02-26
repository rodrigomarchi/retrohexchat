defmodule RetroHexChatWeb.SoloSessionLive do
  @moduledoc """
  LiveView for single-player arcade sessions.
  Provides game selection from Arcade.Catalog and an iframe-based WASM game player.
  No WebRTC, no peer — isolated from the P2P game system.
  """

  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Arcade
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.Components.{ArcadeFrame, GameLobby, SoloLobby}

  @pubsub RetroHexChat.PubSub

  @impl true
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- verify_nickname(socket, nickname),
         {:ok, user_id} <- resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- verify_creator(user_id, db_session),
         :ok <- verify_not_terminal(db_session) do
      mount_arcade_lobby(socket, token, nickname, user_id, db_session)
    else
      {:expired, reason} ->
        {:ok, assign(socket, expired: true, expired_reason: expired_reason_label(reason))}

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
        <GameLobby.game_expired reason={@expired_reason} />
      </div>
    </div>
    """
  end

  def render(%{session_status: "playing"} = assigns) do
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
      <ArcadeFrame.arcade_frame
        game_name={@game_name}
        game_url={@game_url}
        nickname={@nickname}
      />
    </div>
    """
  end

  def render(assigns) do
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
      <SoloLobby.solo_lobby
        nickname={@nickname}
        games={@games}
        session_status={@session_status}
        inactivity_warning={@inactivity_warning}
      />
    </div>
    """
  end

  # --- PubSub Handlers ---

  @impl true
  def handle_info(
        %{event: "arcade_status_changed", payload: %{status: "playing", game_id: game_id}},
        socket
      ) do
    game = resolve_game(game_id)

    socket =
      assign(socket,
        session_status: "playing",
        game_id: game_id,
        game_name: game.name,
        game_url: Arcade.Catalog.game_url(game)
      )

    {:noreply, socket}
  end

  def handle_info(%{event: "arcade_status_changed", payload: %{status: status}}, socket) do
    if SoloSession.terminal?(status) do
      {:noreply,
       socket
       |> assign(session_closed: true)
       |> push_event("arcade_close_tab", %{})}
    else
      {:noreply, assign(socket, session_status: status)}
    end
  end

  def handle_info(%{event: "arcade_session_closed", payload: %{reason: _reason}}, socket) do
    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("arcade_close_tab", %{})}
  end

  def handle_info(
        %{event: "arcade_inactivity_warning", payload: %{expires_in_seconds: _secs}},
        socket
      ) do
    {:noreply, assign(socket, inactivity_warning: true)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Client Event Handlers ---

  @impl true
  def handle_event("select_game", %{"game_id" => game_id}, socket) do
    case Arcade.select_game(socket.assigns.token, socket.assigns.user_id, game_id) do
      :ok -> {:noreply, socket}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("close_session", _params, socket) do
    Arcade.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("arcade_close_tab", %{})}
  end

  def handle_event("arcade_leave", _params, socket) do
    unless socket.assigns[:session_closed] do
      Arcade.close_session(socket.assigns.token, socket.assigns.user_id, "tab_closed")
    end

    {:noreply, assign(socket, session_closed: true)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if connected?(socket) && socket.assigns[:token] && !socket.assigns[:session_closed] do
      token = socket.assigns.token
      user_id = socket.assigns[:user_id]

      if user_id do
        try do
          Arcade.close_session(token, user_id, "disconnected")
        rescue
          _ -> :ok
        end
      end
    end

    :ok
  end

  # --- Private Helpers ---

  defp mount_arcade_lobby(socket, token, nickname, user_id, db_session) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "arcade:#{token}")
      Arcade.join_session(token, user_id)
    end

    games = Arcade.list_games()

    {game_id, game_name, game_url} = resolve_game_info(db_session)

    socket =
      assign(socket,
        token: token,
        nickname: nickname,
        user_id: user_id,
        games: games,
        session_status: db_session.status,
        inactivity_warning: false,
        game_id: game_id,
        game_name: game_name,
        game_url: game_url,
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
    case Arcade.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:redirect, nil}
    end
  end

  defp verify_creator(user_id, session) do
    if user_id == session.creator_id do
      :ok
    else
      {:redirect, nil}
    end
  end

  defp verify_not_terminal(session) do
    if SoloSession.terminal?(session.status) do
      {:expired, session.closed_reason || session.status}
    else
      :ok
    end
  end

  defp resolve_game_info(%{status: "playing", game_id: game_id}) when is_binary(game_id) do
    game = resolve_game(game_id)
    {game_id, game.name, Arcade.Catalog.game_url(game)}
  end

  defp resolve_game_info(_session), do: {nil, nil, nil}

  defp resolve_game(game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} -> game
      _ -> %{id: game_id, name: game_id, engine: :doom}
    end
  end

  defp expired_reason_label("user_closed"), do: "Session closed by user."
  defp expired_reason_label("tab_closed"), do: "Session closed (disconnected)."
  defp expired_reason_label("disconnected"), do: "Session closed (disconnected)."
  defp expired_reason_label("expired"), do: "Session expired due to inactivity."
  defp expired_reason_label("game_over"), do: "Game session ended."
  defp expired_reason_label("pending_timeout"), do: "Session expired."
  defp expired_reason_label("lobby_inactivity"), do: "Session expired due to inactivity."
  defp expired_reason_label(_reason), do: "Arcade session ended."
end
