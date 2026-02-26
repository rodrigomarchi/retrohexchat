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
  attr :game, :map, default: nil
  attr :game_name, :string, default: nil
  attr :game_id, :string, default: nil
  attr :game_started_at, :string, default: nil
  attr :game_duration, :integer, default: nil

  @spec solo_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def solo_lobby(assigns) do
    ~H"""
    <div class={[
      "game-lobby window",
      @previewed_game && "game-lobby--detail",
      @session_status == "finished" && "game-lobby--finished"
    ]}>
      <div class="title-bar">
        <div class="title-bar-text">
          Arcade — {@nickname}
        </div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_session"></button>
        </div>
      </div>
      <div class="window-body game-lobby__body">
        <%!-- Lobby: arcade header + game picker --%>
        <div :if={@session_status == "lobby" && !@previewed_game} class="arcade-header">
          <Icons.icon_game_arcade class="arcade-header__icon" />
          <div class="arcade-header__text">
            <p class="arcade-header__title">Retro Arcade</p>
            <p class="arcade-header__subtitle">
              Classic games running in your browser via WebAssembly
            </p>
          </div>
        </div>

        <%!-- Detail: game info header with actions --%>
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

        <%!-- Playing state --%>
        <.arcade_playing
          :if={@session_status == "playing"}
          game_name={@game_name}
          game_id={@game_id}
          game_started_at={@game_started_at}
        />

        <%!-- Finished state --%>
        <.arcade_finished
          :if={@session_status == "finished"}
          game={@game}
          game_name={@game_name}
          game_id={@game_id}
          game_duration={@game_duration}
        />

        <.arcade_game_detail
          :if={@session_status == "lobby" && @previewed_game}
          content={@previewed_game.content}
        />

        <.arcade_game_picker
          :if={@session_status == "lobby" && !@previewed_game}
          games={@games}
        />

        <.arcade_lobby_toolbar :if={
          @session_status not in ["playing", "finished"] && !@previewed_game
        } />
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

  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_started_at, :string, default: nil

  defp arcade_playing(assigns) do
    ~H"""
    <div class="arcade-status">
      <div class="arcade-status__icon">
        <GameIcons.game_icon game_id={@game_id} />
      </div>
      <div class="arcade-status__info">
        <h2 class="arcade-status__title">{@game_name}</h2>
        <p class="arcade-status__message">Game in progress...</p>
        <p
          :if={@game_started_at}
          class="arcade-status__timer"
          id="arcade-timer"
          phx-hook="ArcadeTimer"
          data-started-at={@game_started_at}
        >
          0:00
        </p>
      </div>
      <div class="arcade-status__actions">
        <button class="btn-icon" phx-click="close_session">
          <Icons.icon_close class="btn-icon__svg" /> End Session
        </button>
      </div>
    </div>
    """
  end

  attr :game, :map, default: nil
  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_duration, :integer, default: nil

  defp arcade_finished(assigns) do
    ~H"""
    <div class="arcade-finished">
      <%!-- Header: game icon + title + tagline --%>
      <div class="arcade-finished__header">
        <div class="arcade-finished__icon">
          <GameIcons.game_icon game_id={@game_id} />
        </div>
        <div class="arcade-finished__header-info">
          <h2 class="arcade-finished__title">{@game_name}</h2>
          <p :if={@game} class="arcade-finished__tagline">{@game.tagline}</p>
        </div>
      </div>

      <hr class="arcade-finished__divider" />

      <%!-- Session summary --%>
      <div class="arcade-finished__summary">
        <div class="arcade-finished__row">
          <Icons.icon_checkmark class="arcade-finished__row-icon" />
          <span>Session completed</span>
        </div>
        <div :if={@game_duration} class="arcade-finished__row">
          <Icons.icon_clock class="arcade-finished__row-icon" />
          <span>Play time: <strong>{format_duration(@game_duration)}</strong></span>
        </div>
        <div :if={@game} class="arcade-finished__row">
          <Icons.icon_game_arcade class="arcade-finished__row-icon" />
          <span>Engine: {engine_label(@game.engine)}</span>
        </div>
      </div>

      <hr class="arcade-finished__divider" />

      <%!-- Next steps --%>
      <div class="arcade-finished__footer">
        <p class="arcade-finished__thanks">
          Thanks for playing! To start a new game, type <code>/arcade</code> in any channel.
        </p>
        <button class="btn-icon" phx-click="close_session">
          <Icons.icon_close class="btn-icon__svg" /> Close
        </button>
      </div>
    </div>
    """
  end

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes >= 60 do
      hours = div(minutes, 60)
      mins = rem(minutes, 60)
      "#{hours}h #{mins}m #{secs}s"
    else
      "#{minutes}m #{secs}s"
    end
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
