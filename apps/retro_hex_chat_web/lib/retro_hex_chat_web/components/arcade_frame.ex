defmodule RetroHexChatWeb.Components.ArcadeFrame do
  @moduledoc """
  Function component for the WASM game iframe container.
  Renders the Emscripten game inside a retro-styled window with controls.
  """

  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :game_name, :string, required: true
  attr :game_url, :string, required: true
  attr :nickname, :string, required: true

  @spec arcade_frame(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_frame(assigns) do
    ~H"""
    <div class="arcade-frame window">
      <div class="title-bar">
        <div class="title-bar-text">
          {@game_name} — {@nickname}
        </div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_session"></button>
        </div>
      </div>
      <div class="window-body arcade-frame__body">
        <iframe
          id="arcade-game-iframe"
          src={@game_url}
          class="arcade-frame__iframe"
          allowfullscreen
          allow="autoplay; gamepad; pointer-lock"
          tabindex="0"
          phx-hook="ArcadeIframe"
        >
        </iframe>
        <div class="arcade-frame__controls">
          <button class="btn-icon" phx-click="close_session">
            <Icons.icon_close class="btn-icon__svg" /> Leave Game
          </button>
        </div>
      </div>
    </div>
    """
  end
end
