defmodule RetroHexChatWeb.ArcadeGameLive do
  @moduledoc """
  LiveView for the arcade game window — renders a fullscreen iframe
  with the WASM game. Opened in a separate browser window from the lobby.
  On disconnect/close, signals the session server that the game finished.
  """

  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Arcade
  alias RetroHexChat.Services.RegisteredNick

  @pubsub RetroHexChat.PubSub

  @impl true
  def mount(%{"token" => token, "game_id" => game_id}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- verify_nickname(socket, nickname),
         {:ok, user_id} <- resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- verify_creator(user_id, db_session),
         :ok <- verify_playing(db_session, game_id),
         {:ok, game} <- Arcade.get_game(game_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(@pubsub, "arcade:#{token}")
      end

      game_url = Arcade.Catalog.game_url(game)

      socket =
        assign(socket,
          token: token,
          user_id: user_id,
          game_id: game_id,
          game_name: game.name,
          game_url: game_url,
          session_closed: false
        )

      {:ok, socket, layout: false}
    else
      _ -> {:ok, push_navigate(socket, to: ~p"/chat"), layout: false}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="arcade-game" class="arcade-game" phx-hook="ArcadeGame">
      <iframe
        id="arcade-game-iframe"
        src={@game_url}
        class="arcade-game__iframe"
        allowfullscreen
        allow="autoplay; gamepad; pointer-lock"
        tabindex="0"
      >
      </iframe>
    </div>
    """
  end

  @impl true
  def handle_info(%{event: "arcade_session_closed"}, socket) do
    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("arcade_close_tab", %{})}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("game_window_closing", _params, socket) do
    finish_game(socket)
    {:noreply, assign(socket, session_closed: true)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if connected?(socket) && !socket.assigns[:session_closed] do
      finish_game(socket)
    end

    :ok
  end

  defp finish_game(socket) do
    token = socket.assigns[:token]
    user_id = socket.assigns[:user_id]

    if token && user_id do
      try do
        Arcade.finish_game(token, user_id)
      rescue
        _ -> :ok
      end
    end
  end

  defp verify_nickname(socket, nil), do: {:error, push_navigate(socket, to: ~p"/connect")}
  defp verify_nickname(socket, _nickname), do: {:ok, socket}

  defp resolve_user_id(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:error, :not_found}
      nick -> {:ok, nick.id}
    end
  end

  defp fetch_session(token) do
    case Arcade.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp verify_creator(user_id, session) do
    if user_id == session.creator_id, do: :ok, else: {:error, :not_creator}
  end

  defp verify_playing(session, game_id) do
    if session.status == "playing" && session.game_id == game_id do
      :ok
    else
      {:error, :not_playing}
    end
  end
end
