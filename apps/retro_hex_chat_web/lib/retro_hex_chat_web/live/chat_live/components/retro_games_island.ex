defmodule RetroHexChatWeb.ChatLive.Components.RetroGamesIsland do
  @moduledoc """
  Retro Games island for single-player browser-native games.

  The host LiveView owns only a minimal summary for menus/taskbar state. The
  island owns game selection, AI difficulty, canvas readiness and the start/end
  commands sent to the JavaScript hook.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.RetroGamesPanel

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog

  @id "retro-games-island"
  @difficulties ~w(easy normal hard)
  @initial_summary %{status: "library", selected_game: nil}

  @doc "Stable DOM/component id used by the host for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Initial host summary for Retro Games state."
  @spec initial_summary() :: map()
  def initial_summary, do: @initial_summary

  @impl true
  @spec mount(Socket.t()) :: {:ok, Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       games: Catalog.list_solo_games(),
       status: "library",
       selected_game: nil,
       difficulty: "normal",
       canvas_ready: false,
       result: nil,
       error_message: nil
     )}
  end

  @impl true
  @spec update(map(), Socket.t()) :: {:ok, Socket.t()}
  def update(%{action: action}, socket), do: {:ok, handle_action(socket, action)}

  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full">
      <.retro_games_panel
        id="retro-games-panel"
        games={@games}
        status={@status}
        selected_game={@selected_game}
        difficulty={@difficulty}
        canvas_ready={@canvas_ready}
        result={@result}
        error_message={@error_message}
        target={@myself}
      />
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("retro_games_select", %{"game-id" => game_id}, socket) do
    {:noreply, select_game(socket, game_id)}
  end

  def handle_event("retro_games_set_difficulty", %{"difficulty" => difficulty}, socket) do
    {:noreply, assign(socket, difficulty: normalize_difficulty(difficulty))}
  end

  def handle_event("retro_games_start_ai", _params, socket) do
    {:noreply, begin_match(socket)}
  end

  def handle_event("retro_games_play_again", _params, socket) do
    socket =
      socket
      |> assign(status: "ready", canvas_ready: false, result: nil, error_message: nil)
      |> summarize()

    {:noreply, socket}
  end

  def handle_event("retro_games_back", _params, socket) do
    {:noreply, back_to_library(socket)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp handle_action(socket, {:select, game_id}), do: select_game(socket, game_id)
  defp handle_action(socket, {:canvas_ready, game_id}), do: mark_canvas_ready(socket, game_id)
  defp handle_action(socket, {:result, result}), do: finish_match(socket, result)
  defp handle_action(socket, {:error, payload}), do: fail_match(socket, payload)
  defp handle_action(socket, :reset), do: back_to_library(socket)
  defp handle_action(socket, _action), do: socket

  defp select_game(socket, game_id) do
    with true <- Catalog.solo_game_id?(game_id),
         {:ok, game} <- Catalog.get_game(game_id) do
      socket
      |> stop_current_unless(game_id)
      |> assign(
        status: "ready",
        selected_game: game,
        canvas_ready: false,
        result: nil,
        error_message: nil
      )
      |> summarize()
    else
      _ -> back_to_library(socket)
    end
  end

  defp begin_match(
         %{assigns: %{status: "ready", canvas_ready: true, selected_game: game}} = socket
       )
       when is_map(game) do
    socket
    |> assign(status: "playing", result: nil, error_message: nil)
    |> push_event("retro_game_begin", %{game_id: game.id, difficulty: socket.assigns.difficulty})
    |> summarize()
  end

  defp begin_match(socket), do: socket

  defp mark_canvas_ready(%{assigns: %{selected_game: %{id: game_id}}} = socket, game_id) do
    if socket.assigns.status in ["ready", "playing"] do
      assign(socket, canvas_ready: true)
    else
      socket
    end
  end

  defp mark_canvas_ready(socket, _game_id), do: socket

  defp finish_match(
         %{assigns: %{selected_game: %{id: game_id}}} = socket,
         %{"game_id" => game_id} = result
       ) do
    socket
    |> assign(status: "finished", canvas_ready: false, result: result)
    |> summarize()
  end

  defp finish_match(
         %{assigns: %{selected_game: %{id: game_id}}} = socket,
         %{game_id: game_id} = result
       ) do
    socket
    |> assign(status: "finished", canvas_ready: false, result: result)
    |> summarize()
  end

  defp finish_match(socket, _result), do: socket

  defp fail_match(%{assigns: %{selected_game: %{id: game_id}}} = socket, payload) do
    payload_game_id = Map.get(payload, "game_id") || Map.get(payload, :game_id)

    if payload_game_id == game_id do
      socket
      |> assign(
        status: "error",
        canvas_ready: false,
        error_message: dgettext("games", "The game engine could not be loaded."),
        result: nil
      )
      |> summarize()
    else
      socket
    end
  end

  defp fail_match(socket, _payload), do: socket

  defp back_to_library(socket) do
    socket
    |> stop_current_unless(nil)
    |> assign(
      status: "library",
      selected_game: nil,
      canvas_ready: false,
      result: nil,
      error_message: nil
    )
    |> summarize()
  end

  defp stop_current_unless(%{assigns: %{selected_game: %{id: current_id}}} = socket, next_id)
       when current_id != next_id do
    push_event(socket, "retro_game_stop", %{game_id: current_id})
  end

  defp stop_current_unless(socket, _next_id), do: socket

  defp normalize_difficulty(difficulty) when difficulty in @difficulties, do: difficulty
  defp normalize_difficulty(_difficulty), do: "normal"

  defp summarize(socket) do
    send(self(), {:retro_games_summary, summary(socket)})
    socket
  end

  defp summary(socket) do
    %{
      status: socket.assigns.status,
      selected_game: selected_summary(socket.assigns.selected_game)
    }
  end

  defp selected_summary(nil), do: nil
  defp selected_summary(game), do: Map.take(game, [:id, :name])
end
