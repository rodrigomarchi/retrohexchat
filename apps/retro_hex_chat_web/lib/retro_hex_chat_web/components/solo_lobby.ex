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
  attr :previewed_game, :map, default: nil

  @spec solo_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def solo_lobby(assigns) do
    ~H"""
    <div class={["game-lobby window", @previewed_game && "game-lobby--detail"]}>
      <div class="title-bar">
        <div class="title-bar-text">
          Arcade — {@nickname}
        </div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_session"></button>
        </div>
      </div>
      <div class="window-body game-lobby__body">
        <div :if={!@previewed_game} class="arcade-header">
          <Icons.icon_game_arcade class="arcade-header__icon" />
          <div class="arcade-header__text">
            <p class="arcade-header__title">Retro Arcade</p>
            <p class="arcade-header__subtitle">
              Classic games running in your browser via WebAssembly
            </p>
          </div>
        </div>

        <div :if={@previewed_game} class="arcade-detail__header">
          <div class="arcade-detail__icon">
            <GameIcons.game_icon game_id={@previewed_game.game.id} />
          </div>
          <div class="arcade-detail__title-group">
            <h2 class="arcade-detail__name">{@previewed_game.game.name}</h2>
            <p class="arcade-detail__tagline">{@previewed_game.game.tagline}</p>
            <span class="arcade-detail__engine">
              {engine_label(@previewed_game.game.engine)}
            </span>
          </div>
          <div class="arcade-detail__header-actions">
            <button class="btn-icon" phx-click="back_to_grid">
              <Icons.icon_btn_prev class="btn-icon__svg" /> Back
            </button>
            <button
              class="btn-icon arcade-detail__start"
              phx-click="select_game"
              phx-value-game_id={@previewed_game.game.id}
            >
              <Icons.icon_btn_join class="btn-icon__svg" /> Start Game
            </button>
            <button class="btn-icon" phx-click="close_session">
              <Icons.icon_close class="btn-icon__svg" /> Leave
            </button>
          </div>
        </div>

        <.arcade_inactivity_warning :if={@inactivity_warning} />

        <.arcade_game_detail
          :if={@session_status == "lobby" && @previewed_game}
          content={@previewed_game.content}
        />

        <.arcade_game_picker
          :if={@session_status == "lobby" && !@previewed_game}
          games={@games}
        />

        <.arcade_lobby_toolbar :if={!@previewed_game} />
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
          phx-click="preview_game"
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

  attr :content, :map, required: true

  defp arcade_game_detail(assigns) do
    ~H"""
    <div class="arcade-detail__sections">
      <fieldset class="arcade-detail__section">
        <legend>About</legend>
        <div class="arcade-detail__about">
          <p :for={paragraph <- @content.about}>{paragraph}</p>
        </div>
      </fieldset>

      <fieldset :if={@content.controls != []} class="arcade-detail__section">
        <legend>Keyboard Controls</legend>
        <table class="arcade-detail__table">
          <thead>
            <tr>
              <th>Key</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{key, action} <- @content.controls}>
              <td><kbd>{key}</kbd></td>
              <td>{action}</td>
            </tr>
          </tbody>
        </table>
      </fieldset>

      <fieldset :if={@content.tips != []} class="arcade-detail__section">
        <legend>Tips</legend>
        <ul class="arcade-detail__tips">
          <li :for={tip <- @content.tips}>{tip}</li>
        </ul>
      </fieldset>
    </div>
    """
  end

  @engine_labels %{
    doom: "DOOM Engine (PrBoom+)",
    quake: "Quake Engine (QuakeSpasm)",
    quake2: "Quake II Engine",
    wolfenstein: "Wolfenstein 3D Engine",
    halflife: "Half-Life Engine (Xash3D)",
    scummvm: "ScummVM"
  }

  defp engine_label(engine), do: Map.get(@engine_labels, engine, to_string(engine))

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
