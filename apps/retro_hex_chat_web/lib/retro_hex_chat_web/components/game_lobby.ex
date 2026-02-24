defmodule RetroHexChatWeb.Components.GameLobby do
  @moduledoc """
  Function components for the game session lobby UI.
  Includes game picker grid, consent banner, waiting indicator, lobby chat,
  and session status header.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias RetroHexChatWeb.Components.GameIcons
  alias RetroHexChatWeb.Icons

  # --- Main lobby component ---

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true
  attr :messages, :list, required: true
  attr :games, :list, required: true
  attr :game_request, :map, default: nil
  attr :session_status, :string, required: true
  attr :inactivity_warning, :boolean, default: false

  @spec game_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def game_lobby(assigns) do
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
        <.game_lobby_header
          nickname={@nickname}
          peer_nick={@peer_nick}
          peer_online={@peer_online}
          session_status={@session_status}
        />

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

        <.game_lobby_chat
          messages={@messages}
          nickname={@nickname}
        />
      </div>
    </div>
    """
  end

  # --- Expired state ---

  attr :reason, :string, required: true

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
          <p class="p2p-lobby-expired__reason">{@reason}</p>
        </div>
      </div>
    </div>
    """
  end

  # --- Sub-components ---

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true
  attr :session_status, :string, required: true

  defp game_lobby_header(assigns) do
    ~H"""
    <div class="game-lobby__header">
      <span class="game-lobby__title">{@nickname} vs {@peer_nick}</span>
      <span class="game-lobby__status">
        {status_label(@session_status, @peer_online)}
      </span>
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
          <span class="game-picker__tagline">{game.tagline}</span>
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
        <button
          phx-click="respond_game"
          phx-value-accepted="true"
          class="btn-icon"
        >
          <Icons.icon_accept class="btn-icon__svg" /> Accept
        </button>
        <button
          phx-click="respond_game"
          phx-value-accepted="false"
          class="btn-icon"
        >
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

  attr :messages, :list, required: true
  attr :nickname, :string, required: true

  defp game_lobby_chat(assigns) do
    ~H"""
    <div class="game-chat">
      <div class="game-chat__messages" id="game-chat-messages">
        <div
          :for={msg <- @messages}
          class={"game-chat__msg #{if msg.type == "system", do: "game-chat__msg--system"}"}
        >
          <span :if={msg.type != "system"} class="game-chat__nick">{msg.sender_nick}:</span>
          {msg.content}
        </div>
        <div :if={@messages == []} class="game-chat__empty">
          No messages yet. Say hi!
        </div>
      </div>
      <form
        id="game-chat-form"
        class="game-chat__form"
        phx-submit={JS.push("send_lobby_message") |> JS.dispatch("reset", to: "#game-chat-form")}
      >
        <input
          type="text"
          name="content"
          placeholder="Type a message..."
          autocomplete="off"
          class="game-chat__input"
        />
        <button type="submit" class="btn-icon">
          <Icons.icon_send class="btn-icon__svg" /> Send
        </button>
      </form>
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

  @spec status_label(String.t(), boolean()) :: String.t()
  defp status_label("pending", false), do: "Waiting for peer..."
  defp status_label("pending", true), do: "Joining..."
  defp status_label("lobby", _), do: "Pick a game"
  defp status_label("playing", _), do: "Playing"
  defp status_label(_, _), do: ""
end
