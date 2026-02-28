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
        role={:host}
        games={@games}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChatWeb.Icons

  @doc "Renders the game lobby window."
  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :nickname, :string, required: true, doc: "Local player's nickname"
  attr :peer_nick, :string, required: true, doc: "Remote peer's nickname"
  attr :peer_online, :boolean, default: true, doc: "Whether the peer is currently online"

  attr :role, :atom,
    default: :host,
    values: [:host, :guest],
    doc: "Local player role: :host or :guest"

  attr :games, :list,
    default: [],
    doc: "List of %{id, name, icon} maps for the game picker"

  attr :game_request, :map,
    default: nil,
    doc: "Active game request map with :game_id and :requester, or nil"

  attr :session_status, :string, default: "lobby", doc: "Session phase label"
  attr :inactivity_warning, :boolean, default: false, doc: "Show inactivity warning bar"
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
      class={classes(["w-[420px]", @class])}
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
        <%!-- Player badges --%>
        <div class="flex items-center gap-retro-8">
          <div class="flex items-center gap-retro-4">
            <Icons.icon_status_user class="w-4 h-4" />
            <span class="text-xs font-bold">{@nickname}</span>
            <.badge variant="default">
              {if @role == :host, do: "Host", else: "Player 2"}
            </.badge>
          </div>
          <span class="text-xs text-muted-foreground">vs</span>
          <div class="flex items-center gap-retro-4">
            <Icons.icon_status_user class="w-4 h-4" />
            <span class="text-xs font-bold">{@peer_nick}</span>
            <.badge variant={if @peer_online, do: "secondary", else: "outline"}>
              {if @peer_online, do: "Online", else: "Offline"}
            </.badge>
          </div>
        </div>

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
          :if={@game_request != nil and @role == :guest}
          class="flex flex-col gap-retro-4 shadow-retro-field bg-accent px-retro-8 py-retro-8"
        >
          <p class="text-xs font-bold">
            <span class="font-normal">{@game_request.requester}</span>
            wants to play <span class="font-normal">{@game_request.game_id}</span>
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
          :if={@game_request != nil and @role == :host}
          class="flex items-center gap-retro-4 shadow-retro-field bg-accent px-retro-8 py-retro-4 text-xs"
        >
          <Icons.icon_clock class="w-4 h-4 flex-shrink-0 animate-spin" />
          <span>
            Waiting for <strong>{@peer_nick}</strong>
            to accept <strong>{@game_request.game_id}</strong>...
          </span>
        </div>

        <%!-- Game picker grid --%>
        <div :if={@games != [] and @game_request == nil}>
          <p class="text-xs font-bold mb-retro-4">Choose a game:</p>
          <div class="grid grid-cols-3 gap-retro-4">
            <.button
              :for={game <- @games}
              type="button"
              variant="ghost"
              phx-click={@on_select_game}
              phx-value-game_id={game.id}
              class={[
                "shadow-retro-field bg-white p-retro-4 text-center cursor-pointer h-auto",
                "hover:bg-hover-bg active:shadow-retro-sunken flex-col"
              ]}
              data-testid={"game-lobby-game-#{game.id}"}
            >
              <:icon>
                <div class="w-8 h-8 mx-auto mb-retro-2">
                  <.game_icon icon={Map.get(game, :icon)} />
                </div>
              </:icon>
              <p class="text-xs font-bold truncate">{game.name}</p>
            </.button>
          </div>
        </div>

        <%!-- Empty state when no games and no request --%>
        <div
          :if={@games == [] and @game_request == nil}
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

  # ── Private helpers ───────────────────────────────────

  attr :icon, :any, default: nil

  defp game_icon(%{icon: :pong} = assigns),
    do: ~H|<Icons.icon_game_pong class="w-8 h-8" />|

  defp game_icon(%{icon: :doom} = assigns),
    do: ~H|<Icons.icon_game_doom class="w-8 h-8" />|

  defp game_icon(%{icon: :tanks} = assigns),
    do: ~H|<Icons.icon_game_tanks class="w-8 h-8" />|

  defp game_icon(%{icon: :trails} = assigns),
    do: ~H|<Icons.icon_game_trails class="w-8 h-8" />|

  defp game_icon(%{icon: :space} = assigns),
    do: ~H|<Icons.icon_game_space class="w-8 h-8" />|

  defp game_icon(%{icon: :breakout} = assigns),
    do: ~H|<Icons.icon_game_breakout class="w-8 h-8" />|

  defp game_icon(%{icon: :tennis} = assigns),
    do: ~H|<Icons.icon_game_tennis class="w-8 h-8" />|

  defp game_icon(%{icon: :boxing} = assigns),
    do: ~H|<Icons.icon_game_boxing class="w-8 h-8" />|

  defp game_icon(assigns),
    do: ~H|<Icons.icon_game_generic class="w-8 h-8" />|
end
