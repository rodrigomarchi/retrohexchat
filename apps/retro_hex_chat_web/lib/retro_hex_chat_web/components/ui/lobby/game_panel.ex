defmodule RetroHexChatWeb.Components.UI.Lobby.GamePanel do
  @moduledoc """
  Games panel for the universal lobby — the body of the "Games" window.

  Shows the game catalog, the incoming-proposal consent prompt, the "waiting for
  peer" state and, while playing, the game canvas (hosting `LobbyGameCanvasHook`).
  Composed from the button primitive and the game-icon facade.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :game, :map, required: true
  attr :game_request, :map, default: nil
  attr :game_outgoing, :boolean, required: true
  attr :games, :list, required: true
  attr :peer_nick, :string, required: true

  @spec game_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def game_panel(assigns) do
    ~H"""
    <p :if={!@connected} class="text-muted-foreground flex items-center gap-2 p-2 text-xs">
      <Icons.icon_joystick class="h-4 w-4 shrink-0" />
      {dgettext("lobby", "Connect to play a game.")}
    </p>

    <section :if={@connected} class="bg-accent p-1" data-testid="lobby-game-panel">
      <div :if={@game.status == "playing"}>
        <div class="mb-2 flex items-center justify-between">
          <p class="flex items-center gap-1 text-xs font-bold">
            <Icons.icon_joystick class="h-4 w-4" />{dgettext("lobby", "Game in progress")}
          </p>
          <.button size="sm" variant="outline" phx-click="end_game">
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("lobby", "End game")}
          </.button>
        </div>
        <div
          id="lobby-game-canvas"
          phx-hook="LobbyGameCanvasHook"
          phx-update="ignore"
          data-game-id={@game.game_id}
          data-is-host={to_string(@game.is_host)}
          class="flex justify-center"
        >
          <canvas width="640" height="480" class="bg-black"></canvas>
        </div>
      </div>

      <div :if={@game.status != "playing"}>
        <div :if={@game_request && !@game_outgoing} class="mb-3" data-testid="lobby-game-consent">
          <p class="flex items-center gap-1 text-xs">
            <Icons.game_icon game_id={@game_request.game_id} class="h-4 w-4" />
            {dgettext("lobby", "%{peer} wants to play %{game}",
              peer: @game_request.proposer_nick,
              game: @game_request.game_id
            )}
          </p>
          <div class="mt-1 flex gap-2">
            <.button size="sm" phx-click="respond_game" phx-value-accepted="true">
              <:icon><Icons.icon_checkmark class="h-4 w-4" /></:icon>
              {dgettext("lobby", "Accept")}
            </.button>
            <.button size="sm" variant="outline" phx-click="respond_game" phx-value-accepted="false">
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("lobby", "Decline")}
            </.button>
          </div>
        </div>

        <p
          :if={@game_request && @game_outgoing}
          class="text-muted-foreground mb-3 flex items-center gap-1 text-xs"
        >
          <Icons.icon_clock class="h-4 w-4 animate-spin" />
          {dgettext("lobby", "Waiting for %{peer} to accept...", peer: @peer_nick)}
        </p>

        <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <button
            :for={game <- @games}
            type="button"
            phx-click="propose_game"
            phx-value-game_id={game.id}
            disabled={@game_request != nil}
            class="shadow-retro-raised bg-secondary flex items-center gap-2 p-2 text-left text-xs disabled:opacity-50"
            data-testid={"lobby-game-#{game.id}"}
          >
            <Icons.game_icon game_id={game.id} class="h-8 w-8 shrink-0" />
            <span class="min-w-0">
              <span class="block truncate font-bold">{game.name}</span>
              <span class="text-muted-foreground block truncate">{game.tagline}</span>
            </span>
          </button>
        </div>
      </div>
    </section>
    """
  end
end
