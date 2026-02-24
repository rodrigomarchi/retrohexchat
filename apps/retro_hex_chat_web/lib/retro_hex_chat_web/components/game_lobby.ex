defmodule RetroHexChatWeb.Components.GameLobby do
  @moduledoc """
  Function components for the game session lobby UI.
  Includes game picker grid, consent banner, waiting indicator,
  and P2P connection diagram header with host indicator.
  """

  use Phoenix.Component

  alias RetroHexChatWeb.Components.{GameIcons, P2pConnectionDiagram}
  alias RetroHexChatWeb.Icons

  # --- Main lobby component ---

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true
  attr :role, :atom, required: true
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}
  attr :games, :list, required: true
  attr :game_request, :map, default: nil
  attr :session_status, :string, required: true
  attr :inactivity_warning, :boolean, default: false

  @spec game_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def game_lobby(assigns) do
    host_nick = if assigns.role == :creator, do: assigns.nickname, else: assigns.peer_nick

    assigns = assign(assigns, :host_nick, host_nick)

    ~H"""
    <div class="game-lobby window">
      <div class="title-bar">
        <div class="title-bar-text">
          Game Session — {@nickname} and {@peer_nick}
        </div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_session"></button>
        </div>
      </div>
      <div class="window-body game-lobby__body">
        <P2pConnectionDiagram.p2p_connection_diagram
          nickname={@nickname}
          peer_nick={@peer_nick}
          peer_online={@peer_online}
          session_status={@session_status}
          local_info={@local_info}
          peer_info={@peer_info}
        />

        <.game_host_badge host_nick={@host_nick} />

        <.game_inactivity_warning :if={@inactivity_warning} />

        <.game_consent_banner
          :if={
            @game_request && @game_request[:status] == "pending" &&
              @game_request[:requester_nick] != @nickname
          }
          game_request={@game_request}
        />

        <.game_waiting_indicator
          :if={
            @game_request && @game_request[:status] == "pending" &&
              @game_request[:requester_nick] == @nickname
          }
          game_request={@game_request}
        />

        <.game_picker
          :if={
            @session_status == "lobby" &&
              (!@game_request || @game_request[:status] != "pending")
          }
          games={@games}
        />

        <.game_lobby_toolbar />
      </div>
    </div>
    """
  end

  # --- Expired state ---

  attr :reason, :string, required: true
  attr :game_result, :map, default: nil

  @spec game_expired(map()) :: Phoenix.LiveView.Rendered.t()
  def game_expired(assigns) do
    ~H"""
    <div class="game-lobby game-lobby--expired window">
      <div class="title-bar">
        <div class="title-bar-text">Game Session</div>
      </div>
      <div class="window-body game-lobby__body">
        <div class="p2p-lobby-expired">
          <Icons.icon_clock class="p2p-lobby-expired__icon" />
          <p class="p2p-lobby-expired__title">Session Unavailable</p>
          <.game_result_card :if={@game_result} result={@game_result} />
          <p class="p2p-lobby-expired__reason">{@reason}</p>
        </div>
      </div>
    </div>
    """
  end

  # --- Sub-components ---

  attr :host_nick, :string, required: true

  defp game_host_badge(assigns) do
    ~H"""
    <div class="game-host-badge">
      {@host_nick} is the host (Player 1)
    </div>
    """
  end

  attr :games, :list, required: true

  defp game_picker(assigns) do
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
        </button>
      </div>
    </div>
    """
  end

  attr :game_request, :map, required: true

  defp game_consent_banner(assigns) do
    game_name = assigns.game_request[:game_id] || "a game"

    assigns = assign(assigns, :game_name, game_name)

    ~H"""
    <div class="game-consent">
      <p class="game-consent__text">
        {@game_request.requester_nick} wants to play: {@game_name}
      </p>
      <div class="game-consent__actions">
        <button phx-click="respond_game" phx-value-accepted="true" class="btn-icon">
          <Icons.icon_accept class="btn-icon__svg" /> Accept
        </button>
        <button phx-click="respond_game" phx-value-accepted="false" class="btn-icon">
          <Icons.icon_reject class="btn-icon__svg" /> Decline
        </button>
      </div>
    </div>
    """
  end

  attr :game_request, :map, required: true

  defp game_waiting_indicator(assigns) do
    ~H"""
    <div class="game-waiting">
      Waiting for response: {@game_request[:game_id]}...
    </div>
    """
  end

  defp game_lobby_toolbar(assigns) do
    ~H"""
    <div class="game-lobby__toolbar">
      <button class="btn-icon" phx-click="close_session">
        <Icons.icon_close class="btn-icon__svg" /> Leave
      </button>
    </div>
    """
  end

  attr :result, :map, required: true

  defp game_result_card(assigns) do
    score = assigns.result["score"] || %{}
    p1 = score["p1"] || 0
    p2 = score["p2"] || 0
    winner = assigns.result["winner"]

    assigns = assign(assigns, p1: p1, p2: p2, winner: winner)

    ~H"""
    <div class="game-result">
      <div class="game-result__title">FINAL SCORE</div>
      <div class="game-result__scores">
        <span class={"game-result__player #{if @winner == 1, do: "game-result__player--winner"}"}>
          P1
        </span>
        <span class="game-result__score">{@p1} &times; {@p2}</span>
        <span class={"game-result__player #{if @winner == 2, do: "game-result__player--winner"}"}>
          P2
        </span>
      </div>
      <div :if={@winner} class="game-result__winner">
        Player {@winner} wins!
      </div>
    </div>
    """
  end

  defp game_inactivity_warning(assigns) do
    ~H"""
    <div class="game-inactivity">
      Session will be closed due to inactivity soon. Send a message to keep it active.
    </div>
    """
  end
end
