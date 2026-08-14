defmodule RetroHexChatWeb.ChatLive.RetroGamesEvents do
  @moduledoc """
  Host-side event adapter for the Retro Games single-player window.

  The LiveView parent opens/focuses the desktop window and forwards canvas
  lifecycle events to `RetroGamesIsland`. The island owns the selected game and
  match state.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.ChatLive.Components.RetroGamesIsland
  alias RetroHexChatWeb.ChatLive.Windows

  @window "retro-games"

  @spec handle_event(String.t(), map(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_event("open_retro_games", params, socket) do
    maybe_select_game(params)
    {:halt, Windows.open(socket, @window)}
  end

  def handle_event("retro_game_canvas_ready", params, socket) do
    send_update(RetroGamesIsland,
      id: RetroGamesIsland.id(),
      action: {:canvas_ready, game_id(params)}
    )

    {:halt, socket}
  end

  def handle_event("retro_game_result", params, socket) do
    send_update(RetroGamesIsland, id: RetroGamesIsland.id(), action: {:result, params})
    {:halt, socket}
  end

  def handle_event("retro_game_error", params, socket) do
    send_update(RetroGamesIsland, id: RetroGamesIsland.id(), action: {:error, params})
    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_info({:retro_games_summary, summary}, socket) do
    {:halt, assign(socket, retro_games: summary)}
  end

  def handle_info(_msg, socket), do: {:cont, socket}

  defp maybe_select_game(%{"game-id" => game_id}) when is_binary(game_id) do
    action = if Catalog.solo_game_id?(game_id), do: {:select, game_id}, else: :reset
    send_update(RetroGamesIsland, id: RetroGamesIsland.id(), action: action)
  end

  defp maybe_select_game(_params), do: :ok

  defp game_id(%{"game_id" => game_id}), do: game_id
  defp game_id(%{game_id: game_id}), do: game_id
  defp game_id(_params), do: nil
end
