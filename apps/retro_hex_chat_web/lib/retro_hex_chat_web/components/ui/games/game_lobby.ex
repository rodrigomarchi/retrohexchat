defmodule RetroHexChatWeb.Components.UI.GameLobby do
  @moduledoc """
  P2P game lobby component for the showcase design system.

  Composed from window + button + badge primitives.
  Displays the game lobby with player info, game picker grid,
  game consent banner, waiting indicator, and inactivity warning.

  ## Usage

      <.game_lobby
        id="game-lobby"
        nickname="alice"
        peer_nick="bob"
        role={:creator}
        games={@games}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram

  alias RetroHexChatWeb.Icons

  @doc "Renders the game lobby window."
  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :nickname, :string, required: true, doc: "Local player's nickname"
  attr :peer_nick, :string, required: true, doc: "Remote peer's nickname"
  attr :peer_online, :boolean, default: true, doc: "Whether the peer is currently online"

  attr :role, :atom,
    default: :creator,
    values: [:creator, :peer],
    doc: "Local player role: :creator or :peer"

  attr :games, :list,
    default: [],
    doc: "List of %{id, name} maps for the game picker"

  attr :game_request, :map,
    default: nil,
    doc: "Active game request map with :game_name, :game_id and :requester_nick, or nil"

  attr :session_status, :string, default: "lobby", doc: "Session phase label"
  attr :inactivity_warning, :boolean, default: false, doc: "Show inactivity warning bar"
  attr :local_info, :map, default: %{}, doc: "Local peer client info for connection diagram"
  attr :peer_info, :map, default: %{}, doc: "Remote peer client info for connection diagram"
  attr :on_select_game, :any, default: nil, doc: "Game card click callback (phx-value-game_id)"
  attr :on_respond_game, :any, default: nil, doc: "Accept/Decline callback (phx-value-accepted)"
  attr :on_close, :any, default: nil, doc: "Leave/close button callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec game_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def game_lobby(assigns) do
    ~H"""
    <.window
      :if={@show}
      class={classes(["w-full max-w-[600px]", @class])}
      data-testid="game-lobby"
      {@rest}
    >
      <.window_title_bar
        title={"Game Lobby \u2014 #{@nickname} vs #{@peer_nick}"}
        controls={[:close]}
        on_close={@on_close}
      >
        <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Connection diagram with peer info --%>
        <.p2p_connection_diagram
          nickname={@nickname}
          peer_nick={@peer_nick}
          peer_online={@peer_online}
          session_status={@session_status}
          local_info={@local_info}
          peer_info={@peer_info}
        />

        <%!-- Inactivity warning --%>
        <div
          :if={@inactivity_warning}
          class="flex items-center gap-retro-4 shadow-retro-field bg-warning-light px-retro-8 py-retro-4 text-xs"
        >
          <Icons.icon_warning class="w-4 h-4 flex-shrink-0" />
          <span>Inactivity detected — this lobby will close soon if no game is selected.</span>
        </div>

        <%!-- Game consent banner (guest sees accept/decline) --%>
        <div
          :if={@game_request != nil and @role == :peer}
          class="flex flex-col gap-retro-4 shadow-retro-field bg-accent px-retro-8 py-retro-8"
        >
          <p class="text-xs font-bold">
            <span class="font-normal">{@game_request.requester_nick}</span>
            wants to play <span class="font-normal">{@game_request.game_name}</span>
          </p>
          <div class="flex gap-retro-4">
            <.button
              size="sm"
              variant="default"
              phx-click={@on_respond_game}
              phx-value-accepted="true"
              data-testid="game-lobby-accept"
            >
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              Accept
            </.button>
            <.button
              size="sm"
              variant="destructive"
              phx-click={@on_respond_game}
              phx-value-accepted="false"
              data-testid="game-lobby-decline"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              Decline
            </.button>
          </div>
        </div>

        <%!-- Waiting indicator (host sees this after sending a request) --%>
        <div
          :if={@game_request != nil and @role == :creator}
          class="flex items-center gap-retro-4 shadow-retro-field bg-accent px-retro-8 py-retro-4 text-xs"
        >
          <Icons.icon_clock class="w-4 h-4 flex-shrink-0 animate-spin" />
          <span>
            Waiting for <strong>{@peer_nick}</strong>
            to accept <strong>{@game_request.game_name}</strong>...
          </span>
        </div>

        <%!-- Game picker grid (host only) --%>
        <div :if={@role == :creator and @games != [] and @game_request == nil}>
          <p class="text-xs font-bold mb-retro-4">Choose a game:</p>
          <div class="grid grid-cols-5 gap-retro-4">
            <button
              :for={game <- @games}
              type="button"
              phx-click={@on_select_game}
              phx-value-game_id={game.id}
              class="shadow-retro-field bg-white p-retro-4 flex flex-col items-center justify-center gap-retro-2 cursor-pointer hover:bg-hover-bg active:shadow-retro-sunken"
              data-testid={"game-lobby-game-#{game.id}"}
            >
              <Icons.game_icon game_id={game.id} class="w-8 h-8" />
              <p class="text-xs font-bold text-center w-full truncate">{game.name}</p>
            </button>
          </div>
        </div>

        <%!-- Waiting state (guest waits for host to pick a game) --%>
        <div
          :if={@role == :peer and @game_request == nil}
          class="flex items-center gap-retro-4 shadow-retro-field bg-white px-retro-8 py-retro-8 text-xs"
        >
          <Icons.icon_clock class="w-4 h-4 flex-shrink-0 animate-spin" />
          <span>Waiting for <strong>{@peer_nick}</strong> to choose a game...</span>
        </div>

        <%!-- Empty state (host, no games available) --%>
        <div
          :if={@role == :creator and @games == [] and @game_request == nil}
          class="shadow-retro-field bg-white p-retro-16 text-center text-xs text-muted-foreground"
        >
          No games available
        </div>

        <%!-- Leave button --%>
        <div class="flex justify-end">
          <.button
            variant="outline"
            phx-click={@on_close}
            data-testid="game-lobby-leave"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            Leave
          </.button>
        </div>
      </.window_body>

      <%!-- Status bar --%>
      <.window_status_bar>
        <.window_status_bar_field grow={true}>
          {@session_status}
        </.window_status_bar_field>
      </.window_status_bar>
    </.window>
    """
  end
end
