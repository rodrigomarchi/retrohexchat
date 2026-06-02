defmodule RetroHexChatWeb.App.SoloSessionLive do
  @moduledoc """
  Solo arcade session using app UI components.
  Provides game selection from Arcade.Catalog and an iframe-based WASM game player.
  No WebRTC, no peer — isolated from the P2P game system.
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
  import RetroHexChatWeb.Components.UI.SoloLobby

  alias RetroHexChat.Arcade
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChatWeb.App.SessionHelpers

  @pubsub RetroHexChat.PubSub

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- SessionHelpers.verify_nickname(socket, nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
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

  # --- PubSub Handlers ---

  @impl true
  def handle_info(
        %{
          event: "arcade_status_changed",
          payload: %{status: "playing", game_id: game_id} = payload
        },
        socket
      ) do
    game = resolve_game(game_id)
    started_at = Map.get(payload, :started_at)

    game_url = Arcade.Catalog.game_url(game)

    socket =
      socket
      |> assign(
        session_status: "playing",
        game: game,
        game_id: game_id,
        game_name: game.name,
        game_started_at: started_at,
        previewed_game: nil
      )
      |> push_event("open_game_window", %{url: game_url})

    {:noreply, socket}
  end

  def handle_info(
        %{
          event: "arcade_status_changed",
          payload: %{status: "finished"} = payload
        },
        socket
      ) do
    duration = Map.get(payload, :duration_seconds, 0)
    notify_session_ended(socket, "game_over")

    {:noreply,
     assign(socket,
       session_status: "finished",
       session_closed: true,
       game_duration: duration
     )}
  end

  def handle_info(%{event: "arcade_status_changed", payload: %{status: status}}, socket) do
    if SoloSession.terminal?(status) do
      unless socket.assigns[:session_closed], do: notify_session_ended(socket, status)

      {:noreply,
       socket
       |> assign(session_closed: true)
       |> push_event("arcade_close_tab", %{})}
    else
      {:noreply, assign(socket, session_status: status)}
    end
  end

  def handle_info(%{event: "arcade_session_closed", payload: %{reason: reason}}, socket) do
    unless socket.assigns[:session_closed], do: notify_session_ended(socket, reason)

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
  def handle_event("preview_game", %{"game-id" => game_id}, socket) do
    preview_game_by_id(socket, game_id)
  end

  def handle_event("preview_game", %{"game_id" => game_id}, socket) do
    preview_game_by_id(socket, game_id)
  end

  def handle_event("back_to_grid", _params, socket) do
    {:noreply, assign(socket, previewed_game: nil)}
  end

  def handle_event("select_game", %{"game-id" => game_id}, socket) do
    select_game_by_id(socket, game_id)
  end

  def handle_event("select_game", %{"game_id" => game_id}, socket) do
    select_game_by_id(socket, game_id)
  end

  def handle_event("close_session", _params, socket) do
    Arcade.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("arcade_close_tab", %{})}
  end

  def handle_event("game_window_closed", _params, socket) do
    if socket.assigns.session_status == "playing" do
      Arcade.finish_game(socket.assigns.token, socket.assigns.user_id)
    end

    {:noreply, socket}
  end

  def handle_event("game_window_blocked", _params, socket) do
    if socket.assigns.session_status == "playing" do
      Arcade.finish_game(socket.assigns.token, socket.assigns.user_id)
    end

    {:noreply,
     assign(socket,
       session_status: "lobby",
       game: nil,
       game_id: nil,
       game_name: nil,
       game_started_at: nil,
       game_duration: nil,
       previewed_game: nil
     )}
  end

  def handle_event("arcade_leave", _params, socket) do
    unless socket.assigns[:session_closed] do
      Arcade.close_session(socket.assigns.token, socket.assigns.user_id, "tab_closed")
      notify_session_ended(socket, "tab_closed")
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
          notify_session_ended(socket, "disconnected")
        rescue
          _ -> :ok
        end
      end
    end

    :ok
  end

  # --- Private Helpers ---

  defp preview_game_by_id(socket, game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} ->
        content =
          case Arcade.get_game_content(game_id) do
            {:ok, c} -> c
            {:error, _} -> %{about: [game.description], controls: [], tips: []}
          end

        previewed = %{
          id: game.id,
          name: game.name,
          description: Map.get(game, :tagline, game.description),
          engine: game.engine,
          about: content.about,
          controls: content.controls,
          tips: content.tips
        }

        {:noreply, assign(socket, previewed_game: previewed)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp select_game_by_id(socket, game_id) do
    case Arcade.select_game(socket.assigns.token, socket.assigns.user_id, game_id) do
      :ok -> {:noreply, socket}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  defp notify_session_ended(socket, reason) do
    nickname = socket.assigns[:nickname]
    game_name = socket.assigns[:game_name]
    token = socket.assigns[:token]

    if nickname && token do
      duration_secs =
        case Arcade.get_session(token) do
          {:ok, s} -> s.duration_seconds
          _ -> nil
        end

      Phoenix.PubSub.broadcast(
        @pubsub,
        "user:#{nickname}",
        %{
          event: "arcade_session_ended",
          payload: %{
            game_name: game_name,
            reason: reason,
            duration_seconds: duration_secs
          }
        }
      )
    end
  rescue
    _ -> :ok
  end

  defp mount_arcade_lobby(socket, token, nickname, user_id, db_session) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "arcade:#{token}")
      Arcade.join_session(token, user_id)
    end

    games = Arcade.list_games()

    {game_id, game_name} = resolve_game_info(db_session)

    socket =
      assign(socket,
        token: token,
        nickname: nickname,
        user_id: user_id,
        games: games,
        session_status: db_session.status,
        inactivity_warning: false,
        game: nil,
        game_id: game_id,
        game_name: game_name,
        game_started_at: nil,
        game_duration: nil,
        session_closed: false,
        previewed_game: nil
      )

    {:ok, socket}
  end

  defp fetch_session(token) do
    case Arcade.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:redirect, nil}
    end
  end

  defp verify_creator(user_id, session) do
    if user_id == session.creator_id, do: :ok, else: {:redirect, nil}
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
    {game_id, game.name}
  end

  defp resolve_game_info(_session), do: {nil, nil}

  defp resolve_game(game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} -> game
      _ -> %{id: game_id, name: game_id, engine: :doom}
    end
  end

  defp expired_reason_label("user_closed"), do: dgettext("games", "Session closed by user.")
  defp expired_reason_label("tab_closed"), do: dgettext("games", "Session closed (disconnected).")

  defp expired_reason_label("disconnected"),
    do: dgettext("games", "Session closed (disconnected).")

  defp expired_reason_label("expired"),
    do: dgettext("games", "Session expired due to inactivity.")

  defp expired_reason_label("game_over"), do: dgettext("games", "Game session ended.")
  defp expired_reason_label("pending_timeout"), do: dgettext("games", "Session expired.")

  defp expired_reason_label("lobby_inactivity"),
    do: dgettext("games", "Session expired due to inactivity.")

  defp expired_reason_label(_reason), do: dgettext("games", "Arcade session ended.")
end
