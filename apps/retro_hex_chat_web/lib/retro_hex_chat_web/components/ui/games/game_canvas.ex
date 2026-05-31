defmodule RetroHexChatWeb.Components.UI.GameCanvas do
  @moduledoc """
  Game canvas container component for the showcase design system.

  Composed from window + button primitives.
  Wraps a game session with a Win98-style window, canvas placeholder,
  player labels, and an End Game control.

  ## Usage

      <.game_canvas
        game_id="game-abc123"
        game_name="Tic-Tac-Toe"
        nickname="alice"
        peer_nick="bob"
        role={:creator}
        on_end_game="end_game"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the game canvas container."
  attr :game_id, :string, required: true
  attr :game_name, :string, required: true
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :role, :atom, default: :peer, values: [:creator, :peer]
  attr :on_end_game, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec game_canvas(map()) :: Phoenix.LiveView.Rendered.t()
  def game_canvas(assigns) do
    ~H"""
    <.window
      class={classes(["w-full max-w-[440px]", @class])}
      data-testid="game-canvas"
      data-game-id={@game_id}
      data-is-host={to_string(@role == :creator)}
      {@rest}
    >
      <.window_title_bar
        title={
          dgettext("games", "%{game} — %{nickname} vs %{peer}",
            game: @game_name,
            nickname: @nickname,
            peer: @peer_nick
          )
        }
        controls={[:minimize, :close]}
      >
        <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Canvas area --%>
        <div class="shadow-retro-field bg-black h-[400px] relative overflow-hidden">
          <canvas id="game-surface" width="640" height="480" class="w-full h-full"></canvas>
          <p class="game-canvas__stub absolute inset-0 flex items-center justify-center text-xs text-gray-400">
            {dgettext("games", "Game engine initializing... Waiting for WebRTC connection.")}
          </p>
        </div>

        <%!-- Controls bar --%>
        <div class="flex items-center justify-between gap-retro-8">
          <%!-- Player labels --%>
          <div class="flex items-center gap-retro-8 text-xs">
            <div class="flex items-center gap-retro-2">
              <Icons.icon_status_user class="w-3 h-3 shrink-0" />
              <span class="font-bold">{@nickname}</span>
              <span :if={@role == :creator} class="text-muted-foreground">
                {dgettext("games", "(host)")}
              </span>
            </div>
            <span class="text-muted-foreground">{dgettext("games", "vs")}</span>
            <div class="flex items-center gap-retro-2">
              <Icons.icon_status_user class="w-3 h-3 shrink-0" />
              <span class="font-bold">{@peer_nick}</span>
              <span :if={@role != :creator} class="text-muted-foreground">
                {dgettext("games", "(host)")}
              </span>
            </div>
          </div>

          <%!-- End Game button --%>
          <.button
            variant="destructive"
            size="sm"
            phx-click={@on_end_game}
            data-testid="game-canvas-end"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("games", "End Game")}
          </.button>
        </div>
      </.window_body>
    </.window>
    """
  end
end
