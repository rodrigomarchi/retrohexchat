defmodule RetroHexChatWeb.Components.UI.Lobby.GamePanel do
  @moduledoc """
  Games activity for the P2P session console.

  Before a game is named, the section lists the games to propose. From the
  proposal on, the game is on its stage (`Games.GameStage`), as every Retro
  Game is: the canvas (hosting `LobbyGameCanvasHook`) fills the section, and
  the consent prompt, the wait, the menu over a running match (Esc or the
  corner key; the match goes on under it) and the final score are the stage's
  menu. The menu's open state is the island's (`target`).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.IconWell
  import RetroHexChatWeb.Components.UI.MediaSession.StatusHeader
  import RetroHexChatWeb.Components.UI.Lobby.PanelParts
  import RetroHexChatWeb.Components.UI.NickFlag

  import RetroHexChatWeb.Components.UI.Games.ArcadeIcon
  import RetroHexChatWeb.Components.UI.Games.GameStage

  alias RetroHexChat.Games.Result
  alias RetroHexChatWeb.Components.UI.LiveMatch
  alias RetroHexChatWeb.Components.UI.RetroGamesPanel
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

  attr :menu_open, :boolean, default: false, doc: "the menu open over a running match"
  attr :target, :any, default: nil, doc: "the island, for the menu's open and close"

  @spec game_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def game_panel(assigns) do
    assigns = assign(assigns, :staged, staged?(assigns.game, assigns.game_request))

    ~H"""
    <.disconnected_section
      :if={!@connected}
      title={dgettext("lobby", "Games")}
      icon={:icon_joystick}
      text={dgettext("lobby", "Connect to play a game.")}
      testid="p2p-games-disconnected"
      header_testid="p2p-games-activity-header"
    />

    <%!-- A game proposed, played or just finished is on its stage, as every
          Retro Game is: the game fills the section, and the question, the
          wait and the result are its menu over it. --%>
    <.game_stage
      :if={@connected and @staged}
      id="lobby-game-stage"
      class="h-full"
      data-testid="lobby-game-stage"
      menu_open={@game.status != "playing" or @menu_open}
      menu_lock={@game.status != "playing"}
      on_close={JS.push("game_menu_close", target: @target)}
      on_menu={@game.status == "playing" && JS.push("game_menu", target: @target)}
      pad={@game.status == "playing" && RetroGamesPanel.game_pad(%{id: @game.game_id})}
      pad_idle={@menu_open}
      game_id={@game.game_id}
    >
      <div
        :if={@game.status == "playing"}
        id="lobby-game-canvas"
        phx-hook="LobbyGameCanvasHook"
        phx-update="ignore"
        data-game-id={@game.game_id}
        data-is-host={to_string(@game.is_host)}
        class="relative h-full w-full"
      >
        <canvas width="640" height="480" class="block h-full w-full bg-black object-contain"></canvas>
      </div>

      <:menu>
        <.consent_menu
          :if={@game_request && !@game_outgoing}
          request={@game_request}
          games={@games}
          peer_nick={@peer_nick}
          peer_locale={@peer_locale}
        />
        <.waiting_menu
          :if={@game_request && @game_outgoing}
          request={@game_request}
          games={@games}
          peer_nick={@peer_nick}
        />
        <.playing_menu
          :if={@game.status == "playing" and @menu_open}
          game={@game}
          games={@games}
          watchers={@watchers}
          watch_url={@watch_url}
          target={@target}
        />
        <.result_menu :if={@game.status == "finished"} game={@game} games={@games} />
      </:menu>
    </.game_stage>

    <section
      :if={@connected and not @staged}
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
          <.badge variant="muted" size="xs" bevel="sunken">
            {dgettext("lobby", "Ready")}
          </.badge>
        </:facets>
      </.media_session_status_header>

      <div class="min-h-0 flex-1 overflow-auto">
        <div
          class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3"
          data-testid="p2p-games-catalog"
        >
          <button
            :for={game <- @games}
            type="button"
            phx-click="propose_game"
            phx-value-game_id={game.id}
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

  # The stage stands from the moment a game is named — proposed, played or
  # just finished; before that the section lists the games to propose.
  defp staged?(%{status: status}, _request) when status in ["playing", "finished"], do: true
  defp staged?(_game, request), do: is_map(request)

  attr :request, :map, required: true
  attr :games, :list, required: true
  attr :peer_nick, :string, required: true
  attr :peer_locale, :string, default: nil

  defp consent_menu(assigns) do
    ~H"""
    <div class="grid justify-items-center gap-retro-6" data-testid="lobby-game-consent">
      <Icons.game_icon game_id={@request.game_id} class="h-12 w-12" />
      <h3 class="arcade-title">{game_name(@games, @request.game_id)}</h3>
      <p class="inline-flex min-w-0 items-center gap-1">
        <.nick_flag :if={@request.proposer_nick == @peer_nick} locale={@peer_locale} />
        {dgettext("lobby", "%{peer} wants to play", peer: @request.proposer_nick)}
      </p>
      <p class="arcade-muted">{dgettext("lobby", "The call stays active while the game runs.")}</p>
      <div class="grid w-full grid-cols-2 gap-retro-6">
        <.button
          variant="arcade"
          aria-label={dgettext("lobby", "Accept game invite")}
          phx-click="respond_game"
          phx-value-accepted="true"
          data-testid="lobby-game-accept"
        >
          <:icon><.arcade_icon name={:play} /></:icon>
          {dgettext("lobby", "Accept")}
        </.button>
        <.button
          variant="arcade-secondary"
          aria-label={dgettext("lobby", "Decline game invite")}
          phx-click="respond_game"
          phx-value-accepted="false"
          data-testid="lobby-game-decline"
        >
          <:icon><.arcade_icon name={:stop} /></:icon>
          {dgettext("lobby", "Decline")}
        </.button>
      </div>
    </div>
    """
  end

  attr :request, :map, required: true
  attr :games, :list, required: true
  attr :peer_nick, :string, required: true

  defp waiting_menu(assigns) do
    ~H"""
    <div class="grid justify-items-center gap-retro-6" data-testid="p2p-games-waiting">
      <Icons.game_icon game_id={@request.game_id} class="h-12 w-12" />
      <h3 class="arcade-title">{game_name(@games, @request.game_id)}</h3>
      <p>{dgettext("lobby", "Waiting for %{peer} to accept...", peer: @peer_nick)}</p>
      <p class="arcade-muted">
        {dgettext("lobby", "The call remains live while the invite is pending.")}
      </p>
      <.button
        variant="arcade-secondary"
        class="w-full"
        aria-label={dgettext("lobby", "Cancel game invite")}
        phx-click="end_game"
        data-testid="lobby-game-cancel"
      >
        <:icon><.arcade_icon name={:stop} /></:icon>
        {dgettext("lobby", "Cancel")}
      </.button>
    </div>
    """
  end

  attr :game, :map, required: true
  attr :games, :list, required: true
  attr :watchers, :integer, default: 0
  attr :watch_url, :string, default: nil
  attr :target, :any, default: nil

  # The match goes on under this menu: a partner's game is not held.
  defp playing_menu(assigns) do
    ~H"""
    <h3 class="arcade-title" data-testid="lobby-game-menu">{game_name(@games, @game.game_id)}</h3>
    <p class="arcade-muted">{dgettext("lobby", "Game in progress")}</p>
    <%!-- A match played in the open says who is looking, and hands over the
          address to watch it at. --%>
    <div :if={@watch_url} class="flex flex-wrap items-center justify-center gap-retro-6">
      <span class="arcade-badge" data-testid="lobby-game-watchers">
        {LiveMatch.watchers_label(@watchers)}
      </span>
      <.button
        type="button"
        variant="arcade-secondary"
        id="lobby-game-watch-copy"
        phx-hook="CopyValueHook"
        data-copy-text={@watch_url}
        data-copied-label={dgettext("share", "Copied!")}
        data-testid="lobby-game-watch-copy"
      >
        <:icon><.arcade_icon name={:link} /></:icon>
        {dgettext("share", "Copy link")}
      </.button>
    </div>
    <.button
      variant="arcade"
      size="lg"
      class="w-full"
      phx-click={JS.push("game_menu_close", target: @target)}
      data-testid="lobby-game-resume"
    >
      <:icon><.arcade_icon name={:play} /></:icon>
      {dgettext("games", "Continue")}
    </.button>
    <div class="grid grid-cols-2 gap-retro-6">
      <.button
        variant="arcade-secondary"
        class="arcade-button--danger"
        phx-click="end_game"
        data-testid="lobby-game-end"
      >
        <:icon><.arcade_icon name={:stop} /></:icon>
        {dgettext("lobby", "End game")}
      </.button>
      <.stage_fullscreen_button stage="lobby-game-stage" />
    </div>
    """
  end

  attr :game, :map, required: true
  attr :games, :list, required: true

  defp result_menu(assigns) do
    ~H"""
    <div class="grid justify-items-center gap-retro-6" data-testid="lobby-game-result">
      <Icons.game_icon game_id={@game.game_id} class="h-12 w-12" />
      <p class="arcade-muted">{dgettext("lobby", "Final Score")}</p>
      <h3 class="arcade-title">{game_name(@games, @game.game_id)}</h3>
      <p class="arcade-badge" data-testid="lobby-game-outcome">{outcome_label(@game)}</p>
      <p class="flex items-center justify-center gap-4">
        <span class={score_class(@game, :p1)}>
          {dgettext("lobby", "P1 %{score}", score: score_of(@game, :p1))}
        </span>
        <span class="arcade-muted">{dgettext("lobby", "×")}</span>
        <span class={score_class(@game, :p2)}>
          {dgettext("lobby", "%{score} P2", score: score_of(@game, :p2))}
        </span>
      </p>
      <%!-- The same game again asks the other side the same question a first
            game does: a rematch is a proposal, not a decision made for them. --%>
      <div class="grid w-full grid-cols-2 gap-retro-6">
        <.button
          variant="arcade"
          phx-click="propose_game"
          phx-value-game_id={@game.game_id}
          data-testid="lobby-game-rematch"
        >
          <:icon><.arcade_icon name={:again} /></:icon>
          {dgettext("lobby", "Rematch")}
        </.button>
        <.button
          variant="arcade-secondary"
          phx-click="dismiss_game_result"
          data-testid="lobby-game-back"
        >
          <:icon><.arcade_icon name={:partner} /></:icon>
          {dgettext("lobby", "Back to games")}
        </.button>
      </div>
    </div>
    """
  end

  @spec peer_label(String.t() | nil) :: String.t()
  defp peer_label(peer) when is_binary(peer) and peer != "", do: peer
  defp peer_label(_peer), do: dgettext("lobby", "peer")

  @spec game_count_label([map()]) :: String.t()
  defp game_count_label(games) do
    dgettext("lobby", "%{count} games", count: length(games))
  end

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
    if outcome(game) == side, do: "arcade-title", else: "arcade-muted"
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
