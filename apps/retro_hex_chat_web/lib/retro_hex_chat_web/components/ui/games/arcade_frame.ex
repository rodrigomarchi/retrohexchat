defmodule RetroHexChatWeb.Components.UI.ArcadeFrame do
  @moduledoc """
  Arcade game iframe container component for the showcase design system.

  Composed from Window primitives.
  Displays a Win98-style window frame with a game area placeholder and
  a Leave Game button.

  ## Usage

      <.arcade_frame
        game_name="Tic Tac Toe"
        game_url="/games/tictactoe"
        nickname="alice"
        on_close="leave_game"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders an arcade game frame container."
  attr :game_name, :string, required: true
  attr :game_url, :string, required: true
  attr :nickname, :string, required: true
  attr :on_close, :any, default: nil, doc: "Callback for leaving the game"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec arcade_frame(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_frame(assigns) do
    ~H"""
    <.window class={classes(["w-[480px]", @class])} data-testid="arcade-frame" {@rest}>
      <.window_title_bar
        title={@game_name}
        controls={[:minimize, :maximize, :close]}
        on_close={@on_close}
      >
        <:icon><Icons.icon_game_arcade class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Player info bar --%>
        <div class="flex items-center justify-between text-xs">
          <div class="flex items-center gap-retro-4">
            <Icons.icon_status_user class="w-4 h-4" />
            <span class="font-bold">{@nickname}</span>
          </div>
          <span class="text-muted-foreground">{@game_name}</span>
        </div>

        <%!-- Game area placeholder --%>
        <div
          class="shadow-retro-sunken bg-white flex items-center justify-center h-[300px]"
          data-testid="arcade-frame-game-area"
        >
          <div class="text-center text-xs text-muted-foreground space-y-retro-4">
            <Icons.icon_game_arcade class="w-8 h-8 mx-auto" />
            <p class="font-bold">{gettext("Game area")}</p>
            <p class="text-muted-foreground">{@game_url}</p>
          </div>
        </div>

        <%!-- Footer controls --%>
        <div class="flex justify-end">
          <.button
            variant="destructive"
            phx-click={@on_close}
            data-testid="arcade-frame-leave"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {gettext("Leave Game")}
          </.button>
        </div>
      </.window_body>
    </.window>
    """
  end
end
