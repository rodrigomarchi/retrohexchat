defmodule RetroHexChatWeb.Components.UI.Lobby.GamePanel do
  @moduledoc """
  Games activity for the P2P session console.

  Shows the game catalog, the incoming-proposal consent prompt, the waiting state,
  the game canvas (hosting `LobbyGameCanvasHook`) while playing, and the
  final-score card once a game ends. Composed from the button/badge primitives,
  media-session primitives, and the game-icon facade.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.MediaSession.ActionButton
  import RetroHexChatWeb.Components.UI.MediaSession.StatusHeader

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
    <section
      :if={!@connected}
      class="flex h-full min-h-[180px] flex-col gap-2 bg-surface p-2"
      data-testid="p2p-games-disconnected"
    >
      <.media_session_status_header
        title={dgettext("lobby", "Games")}
        testid="p2p-games-activity-header"
        class="border border-border bg-canvas p-2 shadow-retro-field"
      >
        <:icon>
          <Icons.icon_joystick class="h-5 w-5 shrink-0" />
        </:icon>
        <:meta>
          <span>{dgettext("lobby", "Waiting for P2P connection")}</span>
        </:meta>
        <:facets>
          <span class="border border-border bg-muted px-1.5 py-0.5 text-[10px] font-bold text-muted-foreground shadow-retro-sunken">
            {dgettext("chat", "Offline")}
          </span>
        </:facets>
      </.media_session_status_header>

      <div class="shadow-retro-field flex min-h-0 flex-1 items-center justify-center bg-white p-4 text-center text-xs text-muted-foreground">
        <div class="max-w-[18rem] space-y-2">
          <Icons.icon_joystick class="mx-auto h-6 w-6" />
          <p>{dgettext("lobby", "Connect to play a game.")}</p>
        </div>
      </div>
    </section>

    <section
      :if={@connected}
      class="flex h-full min-h-[220px] flex-col gap-2 bg-surface p-2"
      data-testid="lobby-game-panel"
    >
      <.media_session_status_header
        title={dgettext("lobby", "Games")}
        testid="p2p-games-activity-header"
        class="border border-border bg-canvas p-2 shadow-retro-field"
      >
        <:icon>
          <Icons.icon_joystick class="h-5 w-5 shrink-0" />
        </:icon>
        <:meta>
          <span>{dgettext("lobby", "Peer %{peer}", peer: peer_label(@peer_nick))}</span>
          <span>{game_count_label(@games)}</span>
        </:meta>
        <:facets>
          <span class={game_status_badge_class(@game, @game_request, @game_outgoing)}>
            {game_status_label(@game, @game_request, @game_outgoing)}
          </span>
        </:facets>
      </.media_session_status_header>

      <div :if={@game.status == "playing"} class="flex min-h-0 flex-1 flex-col gap-2">
        <div class="flex shrink-0 flex-wrap items-center justify-between gap-2 border border-border bg-muted px-2 py-1 shadow-retro-sunken">
          <p class="flex min-w-0 items-center gap-1 text-xs font-bold">
            <Icons.icon_joystick class="h-4 w-4 shrink-0" />
            <span class="truncate">{dgettext("lobby", "Game in progress")}</span>
            <span class="hidden text-muted-foreground sm:inline">
              {game_name(@games, @game.game_id)}
            </span>
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
          class="shadow-retro-field flex min-h-0 flex-1 items-center justify-center overflow-hidden bg-black p-1"
        >
          <canvas
            width="640"
            height="480"
            class="aspect-[4/3] h-auto max-h-full w-full max-w-[720px] bg-black"
          >
          </canvas>
        </div>
      </div>

      <div
        :if={@game.status == "finished"}
        class="shadow-retro-field flex min-h-[220px] flex-1 items-center justify-center bg-white p-4 text-center"
        data-testid="lobby-game-result"
      >
        <div class="w-full max-w-[26rem] border border-border bg-surface p-3 text-left shadow-retro-raised">
          <div class="flex min-w-0 items-start gap-2">
            <span class="shadow-retro-sunken inline-flex h-10 w-10 shrink-0 items-center justify-center bg-canvas">
              <Icons.game_icon game_id={@game.game_id} class="h-6 w-6" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="text-[10px] font-bold uppercase leading-3 text-muted-foreground">
                {dgettext("lobby", "Final Score")}
              </p>
              <p class="truncate text-xs font-bold">{game_name(@games, @game.game_id)}</p>
            </div>
            <.badge variant="default">{outcome_label(@game)}</.badge>
          </div>

          <div class="mt-3 flex items-center justify-center gap-4 border border-border bg-canvas px-2 py-2 text-sm shadow-retro-sunken">
            <span class={["font-bold", score_class(@game, 1)]}>
              {dgettext("lobby", "P1 %{score}", score: score_of(@game, "p1"))}
            </span>
            <span class="text-muted-foreground">{dgettext("lobby", "×")}</span>
            <span class={["font-bold", score_class(@game, 2)]}>
              {dgettext("lobby", "%{score} P2", score: score_of(@game, "p2"))}
            </span>
          </div>

          <div class="mt-3 flex justify-end">
            <.media_session_action_button
              label={dgettext("lobby", "Back to games")}
              phx-click="dismiss_game_result"
            >
              <Icons.icon_joystick class="h-4 w-4" />
              <span>{dgettext("lobby", "Back to games")}</span>
            </.media_session_action_button>
          </div>
        </div>
      </div>

      <div :if={@game.status not in ["playing", "finished"]} class="min-h-0 flex-1 overflow-auto">
        <div
          :if={@game_request && !@game_outgoing}
          class="shadow-retro-field flex h-full min-h-[220px] items-center justify-center bg-white p-3 text-xs sm:min-h-[300px]"
          data-testid="lobby-game-consent"
        >
          <div class="w-full max-w-[30rem] border border-border bg-surface p-2 shadow-retro-raised">
            <div class="flex min-w-0 items-start gap-2">
              <span class="shadow-retro-sunken inline-flex h-10 w-10 shrink-0 items-center justify-center bg-canvas">
                <Icons.game_icon game_id={@game_request.game_id} class="h-6 w-6" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="font-bold">
                  {dgettext("lobby", "%{peer} wants to play", peer: @game_request.proposer_nick)}
                </p>
                <p class="truncate text-muted-foreground">
                  {game_name(@games, @game_request.game_id)}
                </p>
                <p class="mt-1 text-[10px] leading-3 text-muted-foreground">
                  {dgettext("lobby", "The call stays active while the game runs.")}
                </p>
              </div>
            </div>
            <div class="mt-3 flex justify-end gap-1">
              <.media_session_action_button
                label={dgettext("lobby", "Accept game invite")}
                phx-click="respond_game"
                phx-value-accepted="true"
              >
                <Icons.icon_checkmark class="h-4 w-4 text-success" />
                <span>{dgettext("lobby", "Accept")}</span>
              </.media_session_action_button>
              <.media_session_action_button
                label={dgettext("lobby", "Decline game invite")}
                phx-click="respond_game"
                phx-value-accepted="false"
              >
                <Icons.icon_close class="h-4 w-4" />
                <span>{dgettext("lobby", "Decline")}</span>
              </.media_session_action_button>
            </div>
          </div>
        </div>

        <div
          :if={@game_request && @game_outgoing}
          class="shadow-retro-field flex h-full min-h-[220px] items-center justify-center bg-white p-3 text-xs sm:min-h-[300px]"
          data-testid="p2p-games-waiting"
        >
          <div class="w-full max-w-[30rem] border border-border bg-surface p-2 shadow-retro-raised">
            <div class="flex min-w-0 items-start gap-2">
              <span class="shadow-retro-sunken inline-flex h-10 w-10 shrink-0 items-center justify-center bg-canvas">
                <Icons.icon_clock class="h-5 w-5 animate-spin" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="font-bold">
                  {dgettext("lobby", "Waiting for %{peer} to accept...", peer: @peer_nick)}
                </p>
                <p class="truncate text-muted-foreground">
                  {game_name(@games, @game_request.game_id)}
                </p>
                <p class="mt-1 text-[10px] leading-3 text-muted-foreground">
                  {dgettext("lobby", "The call remains live while the invite is pending.")}
                </p>
              </div>
            </div>
            <div class="mt-3 flex justify-end gap-1">
              <.media_session_action_button
                label={dgettext("lobby", "Cancel game invite")}
                phx-click="end_game"
              >
                <Icons.icon_close class="h-4 w-4" />
                <span>{dgettext("lobby", "Cancel")}</span>
              </.media_session_action_button>
            </div>
          </div>
        </div>

        <div
          :if={!@game_request}
          class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3"
          data-testid="p2p-games-catalog"
        >
          <button
            :for={game <- @games}
            type="button"
            phx-click="propose_game"
            phx-value-game_id={game.id}
            disabled={@game_request != nil}
            class="shadow-retro-raised flex min-h-[3.75rem] items-center gap-2 bg-secondary p-2 text-left text-xs disabled:opacity-50"
            data-testid={"lobby-game-#{game.id}"}
          >
            <span class="shadow-retro-sunken inline-flex h-8 w-8 shrink-0 items-center justify-center bg-canvas">
              <Icons.game_icon game_id={game.id} class="h-5 w-5" />
            </span>
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

  @spec peer_label(String.t() | nil) :: String.t()
  defp peer_label(peer) when is_binary(peer) and peer != "", do: peer
  defp peer_label(_peer), do: dgettext("lobby", "peer")

  @spec game_count_label([map()]) :: String.t()
  defp game_count_label(games) do
    dgettext("lobby", "%{count} games", count: length(games))
  end

  @spec game_status_label(map(), map() | nil, boolean()) :: String.t()
  defp game_status_label(%{status: "playing"}, _request, _outgoing),
    do: dgettext("lobby", "Playing")

  defp game_status_label(%{status: "finished"}, _request, _outgoing),
    do: dgettext("lobby", "Finished")

  defp game_status_label(_game, request, true) when is_map(request),
    do: dgettext("lobby", "Waiting")

  defp game_status_label(_game, request, false) when is_map(request),
    do: dgettext("lobby", "Invite")

  defp game_status_label(_game, _request, _outgoing), do: dgettext("lobby", "Ready")

  @spec game_status_badge_class(map(), map() | nil, boolean()) :: String.t()
  defp game_status_badge_class(%{status: "playing"}, _request, _outgoing),
    do:
      "border border-success bg-white px-1.5 py-0.5 text-[10px] font-bold text-success shadow-retro-sunken"

  defp game_status_badge_class(_game, request, _outgoing) when is_map(request),
    do:
      "border border-warning bg-warning-light px-1.5 py-0.5 text-[10px] font-bold text-foreground shadow-retro-sunken"

  defp game_status_badge_class(_game, _request, _outgoing),
    do:
      "border border-border bg-muted px-1.5 py-0.5 text-[10px] font-bold text-muted-foreground shadow-retro-sunken"

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
