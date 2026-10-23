defmodule RetroHexChatWeb.Components.UI.Lobby.GamePanel do
  @moduledoc """
  Games activity for the P2P session console.

  Shows the game catalog, the incoming-proposal consent prompt, the waiting state,
  the game canvas (hosting `LobbyGameCanvasHook`) while playing, and the
  final-score card once a game ends. Composed from the button/badge primitives,
  media-session primitives, and the game-icon facade.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.IconWell
  import RetroHexChatWeb.Components.UI.MediaSession.ActionButton
  import RetroHexChatWeb.Components.UI.MediaSession.StatusHeader
  import RetroHexChatWeb.Components.UI.Lobby.PanelParts
  import RetroHexChatWeb.Components.UI.NickFlag

  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChat.Games.Result
  alias RetroHexChatWeb.Components.UI.LiveMatch
  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :game, :map, required: true
  attr :game_request, :map, default: nil
  attr :game_outgoing, :boolean, required: true
  attr :games, :list, required: true
  attr :peer_nick, :string, required: true
  attr :peer_locale, :string, default: nil, doc: "the peer's language, for the flag"
  attr :watchers, :integer, default: 0, doc: "how many pages are watching the match"

  attr :watch_url, :string,
    default: nil,
    doc: "the address the match is watched at — nil for a match nobody else may watch"

  @spec game_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def game_panel(assigns) do
    ~H"""
    <.disconnected_section
      :if={!@connected}
      title={dgettext("lobby", "Games")}
      icon={:icon_joystick}
      text={dgettext("lobby", "Connect to play a game.")}
      testid="p2p-games-disconnected"
      header_testid="p2p-games-activity-header"
    />

    <section
      :if={@connected}
      class="flex h-full min-h-[220px] flex-col gap-2 bg-surface p-2"
      data-testid="lobby-game-panel"
    >
      <.media_session_status_header
        title={dgettext("lobby", "Games")}
        testid="p2p-games-activity-header"
        class="p-2 shadow-retro-field"
      >
        <:icon>
          <Icons.icon_joystick class="h-5 w-5 shrink-0" />
        </:icon>
        <:meta>
          <span class="inline-flex min-w-0 items-center gap-1">
            <.nick_flag :if={@peer_nick} locale={@peer_locale} />
            {dgettext("lobby", "Peer %{peer}", peer: peer_label(@peer_nick))}
          </span>
          <span>{game_count_label(@games)}</span>
        </:meta>
        <:facets>
          <.badge
            variant={game_status_variant(@game, @game_request, @game_outgoing)}
            size="xs"
            bevel="sunken"
          >
            {game_status_label(@game, @game_request, @game_outgoing)}
          </.badge>
        </:facets>
      </.media_session_status_header>

      <div :if={@game.status == "playing"} class="flex min-h-0 flex-1 flex-col gap-2">
        <%!-- Above the canvas, never over it: a game is played with the
              pointer on the picture, where a hovering dock would sit. --%>
        <div class="flex shrink-0 flex-wrap items-center justify-between gap-2 px-1">
          <p class="flex min-w-0 items-center gap-1 text-xs font-bold">
            <Icons.icon_joystick class="h-4 w-4 shrink-0" />
            <span class="truncate">{dgettext("lobby", "Game in progress")}</span>
            <span class="hidden text-muted-foreground sm:inline">
              {game_name(@games, @game.game_id)}
            </span>
          </p>
          <%!-- A match played in the open says who is looking, and hands
                over the address to watch it at. --%>
          <div :if={@watch_url} class="flex shrink-0 items-center gap-2 text-xs">
            <span class="flex items-center gap-1" data-testid="lobby-game-watchers">
              <Icons.icon_watching class="h-4 w-4 shrink-0" />
              {LiveMatch.watchers_label(@watchers)}
            </span>
            <.button
              type="button"
              size="sm"
              variant="outline"
              id="lobby-game-watch-copy"
              phx-hook="CopyValueHook"
              data-copy-text={@watch_url}
              data-copied-label={dgettext("share", "Copied!")}
              data-testid="lobby-game-watch-copy"
            >
              <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
              {dgettext("share", "Copy link")}
            </.button>
          </div>
          <.tool_button
            label={dgettext("lobby", "End game")}
            caption={dgettext("lobby", "End game")}
            variant="flat"
            size="md"
            phx-click="end_game"
          >
            <Icons.icon_close class="h-4 w-4" />
          </.tool_button>
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

      <.state_card
        :if={@game.status == "finished"}
        class="flex-1"
        data-testid="lobby-game-result"
      >
        <:icon><Icons.game_icon game_id={@game.game_id} class="h-6 w-6" /></:icon>
        <div class="flex min-w-0 items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="text-[10px] font-bold leading-3 text-muted-foreground">
              {dgettext("lobby", "Final Score")}
            </p>
            <p class="truncate font-bold">{game_name(@games, @game.game_id)}</p>
          </div>
          <.badge variant="default">{outcome_label(@game)}</.badge>
        </div>
        <:detail>
          <.inset
            bevel="sunken"
            tone="none"
            class="mt-3 flex items-center justify-center gap-4 border border-border px-2 py-2 text-sm"
          >
            <span class={["font-bold", score_class(@game, :p1)]}>
              {dgettext("lobby", "P1 %{score}", score: score_of(@game, :p1))}
            </span>
            <span class="text-muted-foreground">{dgettext("lobby", "×")}</span>
            <span class={["font-bold", score_class(@game, :p2)]}>
              {dgettext("lobby", "%{score} P2", score: score_of(@game, :p2))}
            </span>
          </.inset>
        </:detail>
        <:actions>
          <%!-- The same game again asks the other side the same question a
                first game does: a rematch is a proposal, not a decision made
                for them. --%>
          <.media_session_action_button
            label={dgettext("lobby", "Rematch")}
            phx-click="propose_game"
            phx-value-game_id={@game.game_id}
            data-testid="lobby-game-rematch"
          >
            <Icons.icon_retry class="h-4 w-4" />
            <span>{dgettext("lobby", "Rematch")}</span>
          </.media_session_action_button>
          <.media_session_action_button
            label={dgettext("lobby", "Back to games")}
            phx-click="dismiss_game_result"
          >
            <Icons.icon_joystick class="h-4 w-4" />
            <span>{dgettext("lobby", "Back to games")}</span>
          </.media_session_action_button>
        </:actions>
      </.state_card>

      <div :if={@game.status not in ["playing", "finished"]} class="min-h-0 flex-1 overflow-auto">
        <.state_card
          :if={@game_request && !@game_outgoing}
          class="h-full"
          data-testid="lobby-game-consent"
        >
          <:icon><Icons.game_icon game_id={@game_request.game_id} class="h-6 w-6" /></:icon>
          <p class="inline-flex min-w-0 items-center gap-1 font-bold">
            <.nick_flag
              :if={@game_request.proposer_nick == @peer_nick}
              locale={@peer_locale}
            />
            {dgettext("lobby", "%{peer} wants to play", peer: @game_request.proposer_nick)}
          </p>
          <p class="truncate text-muted-foreground">{game_name(@games, @game_request.game_id)}</p>
          <p class="mt-1 text-[10px] leading-3 text-muted-foreground">
            {dgettext("lobby", "The call stays active while the game runs.")}
          </p>
          <:actions>
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
          </:actions>
        </.state_card>

        <.state_card
          :if={@game_request && @game_outgoing}
          class="h-full"
          data-testid="p2p-games-waiting"
        >
          <:icon><Icons.icon_clock class="h-5 w-5 animate-spin" /></:icon>
          <p class="font-bold">
            {dgettext("lobby", "Waiting for %{peer} to accept...", peer: @peer_nick)}
          </p>
          <p class="truncate text-muted-foreground">{game_name(@games, @game_request.game_id)}</p>
          <p class="mt-1 text-[10px] leading-3 text-muted-foreground">
            {dgettext("lobby", "The call remains live while the invite is pending.")}
          </p>
          <:actions>
            <.media_session_action_button
              label={dgettext("lobby", "Cancel game invite")}
              phx-click="end_game"
            >
              <Icons.icon_close class="h-4 w-4" />
              <span>{dgettext("lobby", "Cancel")}</span>
            </.media_session_action_button>
          </:actions>
        </.state_card>

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
            class="shadow-retro-raised flex min-h-[3.75rem] items-center gap-2 bg-secondary p-2 text-left text-xs"
            data-testid={"lobby-game-#{game.id}"}
          >
            <.icon_well size="sm">
              <Icons.game_icon game_id={game.id} class="h-5 w-5" />
            </.icon_well>
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

  @spec game_status_variant(map(), map() | nil, boolean()) :: String.t()
  defp game_status_variant(%{status: "playing"}, _request, _outgoing), do: "success"
  defp game_status_variant(_game, request, _outgoing) when is_map(request), do: "warning"
  defp game_status_variant(_game, _request, _outgoing), do: "muted"

  @spec game_name([map()], String.t() | nil) :: String.t()
  defp game_name(games, game_id) do
    case Enum.find(games, &(&1.id == game_id)) do
      %{name: name} -> name
      _ -> to_string(game_id)
    end
  end

  @spec score_of(map(), :p1 | :p2) :: non_neg_integer()
  defp score_of(%{result: %Result{p1_score: score}}, :p1), do: score
  defp score_of(%{result: %Result{p2_score: score}}, :p2), do: score
  defp score_of(_game, _side), do: 0

  @spec score_class(map(), :p1 | :p2) :: String.t()
  defp score_class(game, side) do
    if outcome(game) == side, do: "text-foreground", else: "text-muted-foreground"
  end

  # The host plays P1 and the guest P2, so "you" is whichever side this
  # console's player is on.
  @spec outcome_label(map()) :: String.t()
  defp outcome_label(game) do
    viewer = if game.is_host, do: :p1, else: :p2

    case outcome(game) do
      ^viewer -> dgettext("lobby", "You win!")
      side when side in [:p1, :p2] -> dgettext("lobby", "You lose.")
      :coop_win -> dgettext("lobby", "Cleared together!")
      :coop_loss -> dgettext("lobby", "Out of lives.")
      :draw -> dgettext("lobby", "Draw.")
      _no_verdict -> dgettext("lobby", "Match over.")
    end
  end

  @spec outcome(map()) :: Result.outcome() | nil
  defp outcome(%{result: %Result{outcome: outcome}}), do: outcome
  defp outcome(_game), do: nil
end
