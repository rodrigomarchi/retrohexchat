defmodule RetroHexChatWeb.Components.SoloLobby do
  @moduledoc """
  Function components for the single-player arcade lobby UI.
  Same visual style as the P2P GameLobby but without peer connection,
  consent banner, or WebRTC diagram.
  """

  use Phoenix.Component

  alias RetroHexChatWeb.Components.GameIcons
  alias RetroHexChatWeb.Icons

  # --- Main lobby component ---

  attr :nickname, :string, required: true
  attr :games, :list, required: true
  attr :session_status, :string, required: true
  attr :inactivity_warning, :boolean, default: false

  @spec solo_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def solo_lobby(assigns) do
    ~H"""
    <div class="game-lobby window">
      <div class="title-bar">
        <div class="title-bar-text">
          Arcade — {@nickname}
        </div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_session"></button>
        </div>
      </div>
      <div class="window-body game-lobby__body">
        <div class="arcade-header">
          <Icons.icon_game_arcade class="arcade-header__icon" />
          <div class="arcade-header__text">
            <p class="arcade-header__title">Retro Arcade</p>
            <p class="arcade-header__subtitle">
              Classic games running in your browser via WebAssembly
            </p>
          </div>
        </div>

        <.arcade_inactivity_warning :if={@inactivity_warning} />

        <.arcade_game_picker :if={@session_status == "lobby"} games={@games} />

        <.arcade_lobby_toolbar />
      </div>
    </div>
    """
  end

  # --- Sub-components ---

  attr :games, :list, required: true

  defp arcade_game_picker(assigns) do
    ~H"""
    <div class="game-picker">
      <div class="game-picker__title">Choose a game:</div>
      <div class="game-picker__grid">
        <button
          :for={game <- @games}
          class="game-picker__card"
          phx-click="select_game"
          phx-value-game_id={game.id}
          title={game.description}
        >
          <div class="game-picker__icon">
            <GameIcons.game_icon game_id={game.id} />
          </div>
          <span class="game-picker__name">{game.name}</span>
          <span class="game-picker__tagline">{game.tagline}</span>
        </button>
      </div>
    </div>
    """
  end

  defp arcade_lobby_toolbar(assigns) do
    ~H"""
    <div class="game-lobby__toolbar">
      <button class="btn-icon" phx-click="close_session">
        <Icons.icon_close class="btn-icon__svg" /> Leave
      </button>
    </div>
    """
  end

  defp arcade_inactivity_warning(assigns) do
    ~H"""
    <div class="game-inactivity">
      Session will be closed due to inactivity soon. Select a game to keep it active.
    </div>
    """
  end
end
