defmodule RetroHexChatWeb.ChatLive.ArcadeSessionEvents do
  @moduledoc """
  Host-side state machine and event adapters for the in-chat solo arcade session.

  The chat holds at most ONE arcade session, in the `@arcade_session` assign:

      nil → "lobby" → "playing" → "finished" → nil

  Opening "Games → Arcade" (registered + identified only) creates a solo session
  (`Arcade.create_session` + `join_session`), subscribes to `"arcade:\#{token}"`
  and opens the managed "arcade-games" window with the picker. Selecting a game
  drives the domain (`Arcade.select_game`); the resulting "playing" broadcast
  makes the host push `open_game_window` to the ArcadeSession JS hook, which
  `window.open`s the external WASM game and polls it — its close bubbles back as
  `game_window_closed` → `Arcade.finish_game`.

  Unlike the P2P console islands, the arcade content is a pure read-model of
  this assign, rendered inline (`solo_lobby`) with no island LiveComponent and no
  `send_update`, so there is no mount-patch race to work around. The stable
  `#arcade-session` hook anchor is gated on `@arcade_session` (not the window),
  so the game-window poll survives minimizing or closing the picker while a game
  is running.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Arcade
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Windows

  @pubsub RetroHexChat.PubSub
  @window "arcade-games"

  # ── Client events ─────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_event("open_arcade", _params, socket) do
    {:halt, open_arcade(socket)}
  end

  def handle_event(
        "arcade_preview",
        %{"game-id" => game_id},
        %{assigns: %{arcade_session: %{}}} = socket
      ) do
    {:halt, preview_game(socket, game_id)}
  end

  def handle_event("arcade_back", _params, %{assigns: %{arcade_session: %{} = s}} = socket) do
    {:halt, put_arcade(socket, %{s | previewed_game: nil})}
  end

  def handle_event(
        "arcade_select_game",
        %{"game-id" => game_id},
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    _ = Arcade.select_game(s.token, s.user_id, game_id)
    {:halt, socket}
  end

  # The ArcadeSession JS hook reports the game window closing/blocking.
  def handle_event("game_window_closed", _params, %{assigns: %{arcade_session: %{} = s}} = socket) do
    if s.status == "playing", do: Arcade.finish_game(s.token, s.user_id)
    {:halt, socket}
  end

  def handle_event(
        "game_window_blocked",
        _params,
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    if s.status == "playing", do: Arcade.finish_game(s.token, s.user_id)

    socket =
      Messages.system_event(
        socket,
        dgettext(
          "chat",
          "The game window was blocked. Allow pop-ups for this site and try again."
        )
      )

    {:halt,
     put_arcade(socket, %{
       s
       | status: "lobby",
         game_id: nil,
         game_name: nil,
         game_started_at: nil,
         game_duration: nil,
         previewed_game: nil
     })}
  end

  def handle_event("arcade_leave", _params, %{assigns: %{arcade_session: %{}}} = socket) do
    {:halt, close_arcade(socket, "user_closed")}
  end

  # X on the picker: while a game is running keep the session alive (the popup
  # keeps playing, the hook anchor keeps polling) and only hide the window;
  # otherwise end the session.
  def handle_event(
        "arcade_window_close",
        _params,
        %{assigns: %{arcade_session: %{status: "playing"}}} = socket
      ) do
    {:halt, Windows.close_window(socket, @window)}
  end

  def handle_event("arcade_window_close", _params, %{assigns: %{arcade_session: %{}}} = socket) do
    {:halt, close_arcade(socket, "user_closed")}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── PubSub events (topic "arcade:#{token}") ───────────────────

  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_info(
        %{
          event: "arcade_status_changed",
          payload: %{status: "playing", game_id: game_id} = payload
        },
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    game = resolve_game(game_id)

    socket =
      socket
      |> put_arcade(%{
        s
        | status: "playing",
          game_id: game_id,
          game_name: game.name,
          game_started_at: Map.get(payload, :started_at),
          inactivity_warning: false,
          previewed_game: nil
      })
      |> Windows.open(@window)
      |> push_event("open_game_window", %{url: Arcade.game_url(game)})

    {:halt, socket}
  end

  def handle_info(
        %{event: "arcade_status_changed", payload: %{status: "finished"} = payload},
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    duration = Map.get(payload, :duration_seconds, 0)
    {:halt, put_arcade(socket, %{s | status: "finished", game_duration: duration})}
  end

  def handle_info(
        %{event: "arcade_status_changed", payload: %{status: status}},
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    if SoloSession.terminal?(status) do
      {:halt, clear_arcade(socket, s)}
    else
      {:halt, put_arcade(socket, %{s | status: status})}
    end
  end

  def handle_info(
        %{event: "arcade_session_closed"},
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    {:halt, clear_arcade(socket, s)}
  end

  def handle_info(
        %{event: "arcade_inactivity_warning"},
        %{assigns: %{arcade_session: %{} = s}} = socket
      ) do
    {:halt, put_arcade(socket, %{s | inactivity_warning: true})}
  end

  def handle_info(_msg, socket), do: {:cont, socket}

  # ── Lifecycle ─────────────────────────────────────────────────

  @doc "Close any active arcade session when the chat LiveView terminates."
  @spec close_on_terminate(Socket.t()) :: :ok
  def close_on_terminate(%{assigns: %{arcade_session: %{token: token, user_id: user_id}}}) do
    Arcade.close_session(token, user_id, "disconnected")
    :ok
  rescue
    _ -> :ok
  end

  def close_on_terminate(_socket), do: :ok

  # ── Internal ──────────────────────────────────────────────────

  @spec open_arcade(Socket.t()) :: Socket.t()
  defp open_arcade(socket) do
    cond do
      socket.assigns[:arcade_session] ->
        Windows.open(socket, @window)

      not identified?(socket) ->
        Messages.system_event(
          socket,
          dgettext(
            "chat",
            "You must be registered and identified to play. Use /ns register and /ns identify first."
          )
        )

      true ->
        start_session(socket)
    end
  end

  @spec start_session(Socket.t()) :: Socket.t()
  defp start_session(socket) do
    nickname = socket.assigns.session.nickname

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, %{token: token}} <- Arcade.create_session(user_id) do
      Phoenix.PubSub.subscribe(@pubsub, "arcade:#{token}")
      Arcade.join_session(token, user_id)

      socket
      |> assign(arcade_session: new_session(token, user_id))
      |> Windows.open(@window)
    else
      _ ->
        Messages.system_event(
          socket,
          dgettext("chat", "Could not start the arcade session. Please try again.")
        )
    end
  end

  @spec new_session(String.t(), integer()) :: map()
  defp new_session(token, user_id) do
    %{
      token: token,
      user_id: user_id,
      status: "lobby",
      game_id: nil,
      game_name: nil,
      game_started_at: nil,
      game_duration: nil,
      previewed_game: nil,
      inactivity_warning: false
    }
  end

  @spec preview_game(Socket.t(), String.t()) :: Socket.t()
  defp preview_game(socket, game_id) do
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

        put_arcade(socket, %{socket.assigns.arcade_session | previewed_game: previewed})

      {:error, _} ->
        socket
    end
  end

  @spec close_arcade(Socket.t(), String.t()) :: Socket.t()
  defp close_arcade(socket, reason) do
    s = socket.assigns.arcade_session
    _ = Arcade.close_session(s.token, s.user_id, reason)
    Phoenix.PubSub.unsubscribe(@pubsub, "arcade:#{s.token}")

    socket
    |> assign(arcade_session: nil)
    |> Windows.close_window(@window)
  end

  # Domain-driven teardown (terminal status / session_closed broadcast): the
  # session is already closed server-side — just unsubscribe, drop the assign
  # and unmount the window.
  @spec clear_arcade(Socket.t(), map()) :: Socket.t()
  defp clear_arcade(socket, s) do
    Phoenix.PubSub.unsubscribe(@pubsub, "arcade:#{s.token}")

    socket
    |> Messages.system_event(dgettext("chat", "Arcade session ended."))
    |> assign(arcade_session: nil)
    |> Windows.close_window(@window)
  end

  @spec put_arcade(Socket.t(), map()) :: Socket.t()
  defp put_arcade(socket, session), do: assign(socket, arcade_session: session)

  @spec identified?(Socket.t()) :: boolean()
  defp identified?(socket), do: socket.assigns.session.identified == true

  @spec resolve_game(String.t()) :: map()
  defp resolve_game(game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} -> game
      _ -> %{id: game_id, name: game_id, engine: :doom}
    end
  end
end
