defmodule RetroHexChatWeb.Components.UI.Lobby.GamePanel do
  @moduledoc """
  Games panel for the universal lobby — the body of the "Games" window.

  Shows the game catalog, the incoming-proposal consent prompt, the "waiting for
  peer" state, the game canvas (hosting `LobbyGameCanvasHook`) while playing, and
  the final-score card once a game ends. Composed from the button/badge primitives
  and the game-icon facade.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge

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

      <div
        :if={@game.status == "finished"}
        class="shadow-retro-field bg-white space-y-2 p-4 text-center"
        data-testid="lobby-game-result"
      >
        <p class="text-muted-foreground text-xs font-bold uppercase tracking-wider">
          {dgettext("lobby", "Final Score")}
        </p>
        <div class="text-muted-foreground text-xs">{game_name(@games, @game.game_id)}</div>
        <div class="flex items-center justify-center gap-4 text-sm">
          <span class={["font-bold", score_class(@game, 1)]}>
            {dgettext("lobby", "P1 %{score}", score: score_of(@game, "p1"))}
          </span>
          <span class="text-muted-foreground">{dgettext("lobby", "×")}</span>
          <span class={["font-bold", score_class(@game, 2)]}>
            {dgettext("lobby", "%{score} P2", score: score_of(@game, "p2"))}
          </span>
        </div>
        <div>
          <.badge variant="default">{outcome_label(@game)}</.badge>
        </div>
        <div class="pt-1">
          <.button size="sm" variant="outline" phx-click="dismiss_game_result">
            <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
            {dgettext("lobby", "Back to games")}
          </.button>
        </div>
      </div>

      <div :if={@game.status not in ["playing", "finished"]}>
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

  @spec game_name([map()], String.t() | nil) :: String.t()
  defp game_name(games, game_id) do
    case Enum.find(games, &(&1.id == game_id)) do
      %{name: name} -> name
      _ -> to_string(game_id)
    end
  end

  @spec score_of(map(), String.t()) :: integer()
  defp score_of(game, key) do
    get_in(game, [:result, "score", key]) || 0
  end

  @spec score_class(map(), integer()) :: String.t()
  defp score_class(game, player) do
    if winner(game) == player, do: "text-foreground", else: "text-muted-foreground"
  end

  @spec outcome_label(map()) :: String.t()
  defp outcome_label(game) do
    viewer = if game.is_host, do: 1, else: 2

    case winner(game) do
      w when w in [1, 2] and w == viewer -> dgettext("lobby", "You win!")
      w when w in [1, 2] -> dgettext("lobby", "You lose.")
      _ -> dgettext("lobby", "Draw.")
    end
  end

  @spec winner(map()) :: integer() | nil
  defp winner(game), do: get_in(game, [:result, "winner"])
end
