defmodule RetroHexChatWeb.Components.GameCanvas do
  @moduledoc """
  Function component for the game canvas container.
  Renders the game header, 640×480 canvas surface, and controls.
  """

  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :game_id, :string, required: true
  attr :game_name, :string, required: true
  attr :is_host, :boolean, required: true

  @spec game_canvas(map()) :: Phoenix.LiveView.Rendered.t()
  def game_canvas(assigns) do
    ~H"""
    <div
      id="game-canvas"
      class="game-canvas"
      phx-hook="GameCanvasHook"
      data-game-id={@game_id}
      data-is-host={to_string(@is_host)}
    >
      <div class="game-canvas__header">
        <span class="game-canvas__title">{@game_name}</span>
        <span class="game-canvas__vs">{@nickname} vs {@peer_nick}</span>
      </div>
      <canvas
        id="game-surface"
        class="game-canvas__surface"
        width="640"
        height="480"
      >
      </canvas>
      <p class="game-canvas__stub">
        Game engine initializing... Waiting for WebRTC connection.
      </p>
      <div class="game-canvas__controls">
        <button class="btn-icon" phx-click="end_game">
          <Icons.icon_close class="btn-icon__svg" /> End Game
        </button>
      </div>
    </div>
    """
  end
end
