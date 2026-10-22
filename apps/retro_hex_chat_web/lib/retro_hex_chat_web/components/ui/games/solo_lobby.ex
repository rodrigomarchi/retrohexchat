defmodule RetroHexChatWeb.Components.UI.SoloLobby do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.GameSheet
  alias RetroHexChatWeb.Components.UI.Landing.GameCards
  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Inset

  @doc """
  Renders the multi-state body of the solo arcade window: the game launcher,
  preview, playing and finished states.

  The window chrome (title bar, close control) is supplied by the enclosing
  `desktop_window` — this component renders only the body content. Composed from
  platform primitives (Button, Badge, Icons).
  """
  attr :id, :string, required: true
  attr :groups, :list, required: true, doc: "`RetroHexChatWeb.GameCatalog.arcade_groups/0`"
  attr :session_status, :string, default: "lobby"
  attr :previewed_game, :map, default: nil
  attr :game_name, :string, default: nil
  attr :game_id, :string, default: nil
  attr :game_started_at, :string, default: nil
  attr :game_duration, :integer, default: nil
  attr :timezone, :string, default: "Etc/UTC", doc: "The player's, for the start time"
  attr :inactivity_warning, :boolean, default: false
  attr :on_select_game, :any, default: nil
  attr :on_back, :any, default: nil
  attr :on_back_to_launcher, :any, default: nil
  attr :on_close, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec solo_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def solo_lobby(assigns) do
    ~H"""
    <div id={@id} class={classes(["flex h-full min-h-0 flex-col gap-retro-12", @class])} {@rest}>
      <%!-- Inactivity warning --%>
      <div
        :if={@inactivity_warning}
        class="shadow-retro-field flex shrink-0 items-center gap-retro-4 bg-warning-bg px-retro-8 py-retro-4 text-xs"
      >
        <Icons.icon_warning class="w-4 h-4 flex-shrink-0" />
        <span>
          {dgettext(
            "games",
            "Session will be closed due to inactivity soon. Select a game to keep it active."
          )}
        </span>
      </div>

      <.lobby_launcher
        :if={@session_status == "lobby" && !@previewed_game}
        groups={@groups}
        on_close={@on_close}
      />

      <.lobby_preview
        :if={@session_status == "lobby" && @previewed_game}
        previewed_game={@previewed_game}
        on_select_game={@on_select_game}
        on_back={@on_back}
        on_close={@on_close}
      />

      <.playing_state
        :if={@session_status == "playing"}
        game_name={@game_name}
        game_id={@game_id}
        game_started_at={@game_started_at}
        timezone={@timezone}
        on_back_to_launcher={@on_back_to_launcher}
        on_close={@on_close}
      />

      <.finished_state
        :if={@session_status == "finished"}
        game_name={@game_name}
        game_id={@game_id}
        game_duration={@game_duration}
        on_back_to_launcher={@on_back_to_launcher}
        on_close={@on_close}
      />
    </div>
    """
  end

  # ── Lobby: Game Launcher ────────────────────────────────

  attr :groups, :list, required: true
  attr :on_close, :any, default: nil

  # The same cards, under the same engines, as the public catalogue; a card
  # opens the game's sheet here instead of its page.
  defp lobby_launcher(assigns) do
    assigns =
      assign(assigns, :card_groups, Enum.map(assigns.groups, &card_group/1))

    ~H"""
    <div data-testid="arcade-library" class="flex min-h-0 flex-1 flex-col gap-retro-8">
      <div class="flex items-center gap-retro-12">
        <Icons.icon_game_arcade class="h-8 w-8 flex-shrink-0" />
        <div class="min-w-0">
          <p class="text-sm font-bold">{dgettext("games", "Arcade")}</p>
          <p class="text-xs text-muted-foreground">
            {dgettext("games", "Classic games running in your browser via WebAssembly")}
          </p>
        </div>
      </div>

      <.inset data-testid="arcade-icon-window" class="min-h-0 flex-1 overflow-auto p-retro-10">
        <div data-testid="arcade-icon-grid">
          <GameCards.game_card_groups
            groups={@card_groups}
            columns="grid-cols-2 md:grid-cols-3 lg:grid-cols-4"
          />
        </div>
      </.inset>

      <div
        data-testid="arcade-status-bar"
        class="flex items-center justify-between gap-retro-8 bg-surface px-retro-8 py-retro-4 text-[11px] shadow-retro-field"
      >
        <span>{dgettext("games", "Ready")}</span>
        <span class="font-bold">{dgettext("games", "WebAssembly")}</span>
      </div>
    </div>
    """
  end

  # Each card is the Arcade's own address on its game (`/?arcade=<id>`), so it
  # can be opened, shared or bookmarked like the public page's.
  defp card_group(group) do
    cards =
      Enum.map(
        group.games,
        &%{game: &1, path: Paths.chat_arcade_path(&1.id), testid: "arcade-game-#{&1.id}"}
      )

    %{engine: group.engine, name: group.name, cards: cards}
  end

  # ── Lobby: Game Preview ─────────────────────────────────

  attr :previewed_game, :map, required: true
  attr :on_select_game, :any, default: nil
  attr :on_back, :any, default: nil
  attr :on_close, :any, default: nil

  defp lobby_preview(assigns) do
    ~H"""
    <div
      data-testid="arcade-game-preview"
      class="min-h-0 flex-1 overflow-auto bg-surface p-retro-10 shadow-retro-sunken"
    >
      <GameSheet.game_sheet game={@previewed_game}>
        <:actions>
          <%!-- An anchor, not a scripted `window.open`: `rel="noopener"` is
                what gives the game its own event loop, and without it the tab
                shares this one — measured at 1203 ms against 12 ms.

                The click that tells the server the session started is held with
                the tab rather than fired beside it. `OpenTabConfirmHook` asks
                first, and `data-confirm-event` is what the confirmation replays
                — so a reader who cancels has not started a game. The
                `phx-click` stays for the case the gate is not there to catch it
                (no JavaScript at all), where the anchor and the click go
                together exactly as they used to. --%>
          <.button
            class="font-bold"
            href={Paths.arcade_path(@previewed_game.id)}
            target="_blank"
            rel="noopener"
            phx-click={@on_select_game}
            phx-value-game-id={@previewed_game.id}
            data-confirm-tab="external"
            data-confirm-event={@on_select_game}
            data-confirm-params={Jason.encode!(%{"game-id" => @previewed_game.id})}
            data-testid={"solo-game-start-#{@previewed_game.id}"}
          >
            <:icon><Icons.icon_btn_join class="w-4 h-4" /></:icon>
            {dgettext("games", "Play now")}
          </.button>
          <.button
            variant="outline"
            patch={Paths.localized("/chat/help/" <> @previewed_game.help_topic)}
            data-testid="arcade-how-to-play"
          >
            <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
            {dgettext("games", "How to play")}
          </.button>
          <.button variant="outline" phx-click={@on_back} data-testid="arcade-preview-back">
            <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
            {dgettext("games", "Back")}
          </.button>
          <.button variant="outline" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("games", "Leave")}
          </.button>
        </:actions>
      </GameSheet.game_sheet>
    </div>
    """
  end

  # ── Playing State ───────────────────────────────────────

  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_started_at, :string, default: nil
  attr :timezone, :string, default: "Etc/UTC"
  attr :on_back_to_launcher, :any, default: nil
  attr :on_close, :any, default: nil

  defp playing_state(assigns) do
    ~H"""
    <div
      data-testid="arcade-playing-state"
      class="flex flex-1 flex-col items-center justify-center gap-retro-16 py-retro-16 text-center"
    >
      <div class="flex flex-col items-center gap-retro-8 shadow-retro-field bg-white px-retro-16 py-retro-12 min-w-[240px]">
        <Icons.game_icon game_id={@game_id} class="w-20 h-20 shrink-0" />
        <h3 class="text-base font-bold">{@game_name}</h3>
        <.badge variant="secondary">
          <span class="flex items-center gap-retro-4">
            <Icons.icon_btn_play class="w-3 h-3" />
            {dgettext("games", "Game in progress")}
          </span>
        </.badge>
        <p :if={@game_started_at} class="text-[10px] font-mono text-muted-foreground">
          {dgettext("games", "Started %{time}", time: format_started(@game_started_at, @timezone))}
        </p>
      </div>

      <div class="flex items-start gap-retro-8 shadow-retro-field bg-white px-retro-12 py-retro-8 text-xs max-w-sm text-left">
        <Icons.icon_btn_open class="w-4 h-4 flex-shrink-0 mt-[1px]" />
        <span>
          {dgettext(
            "games",
            "The game runs in a tab of its own, with its own address. Closing that tab does not end the session — End Session does, and so does leaving it alone for a while."
          )}
        </span>
      </div>

      <div class="flex flex-wrap items-center justify-center gap-retro-8">
        <%!-- The way back into a tab that was closed, and the address itself:
              the game's tab has no handle here to reopen, by design. --%>
        <.button
          variant="outline"
          href={Paths.arcade_path(@game_id)}
          target="_blank"
          rel="noopener"
          data-confirm-tab="external"
          data-testid="arcade-reopen"
        >
          <:icon><Icons.icon_btn_open class="w-4 h-4" /></:icon>
          {dgettext("games", "Open the game tab")}
        </.button>
        <.button variant="outline" phx-click={@on_back_to_launcher} data-testid="arcade-back">
          <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
          {dgettext("games", "Back")}
        </.button>
        <.button variant="outline" phx-click={@on_close} data-testid="solo-session-end">
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("games", "End Session")}
        </.button>
      </div>
    </div>
    """
  end

  # ── Finished State ──────────────────────────────────────

  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_duration, :integer, default: nil
  attr :on_back_to_launcher, :any, default: nil
  attr :on_close, :any, default: nil

  defp finished_state(assigns) do
    ~H"""
    <div
      data-testid="arcade-finished-state"
      class="flex flex-1 flex-col items-center justify-center gap-retro-16 py-retro-16 text-center"
    >
      <div class="flex flex-col items-center gap-retro-8 shadow-retro-field bg-white px-retro-16 py-retro-12 min-w-[240px]">
        <Icons.game_icon game_id={@game_id} class="w-20 h-20 shrink-0" />
        <h3 class="text-base font-bold">{@game_name}</h3>
        <.badge variant="secondary">
          <span class="flex items-center gap-retro-4">
            <Icons.icon_checkmark class="w-3 h-3" />
            {dgettext("games", "Session complete")}
          </span>
        </.badge>
        <div :if={@game_duration} class="flex items-center gap-retro-6 text-xs text-muted-foreground">
          <Icons.icon_clock class="w-4 h-4 flex-shrink-0" />
          <span>
            {dgettext("games", "Play time:")}
            <strong>{ChatHelpers.format_duration(@game_duration)}</strong>
          </span>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-center gap-retro-8">
        <.button variant="outline" phx-click={@on_back_to_launcher} data-testid="arcade-back">
          <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
          {dgettext("games", "Back")}
        </.button>
        <.button variant="outline" phx-click={@on_close} data-testid="solo-session-close">
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("games", "Close")}
        </.button>
      </div>
    </div>
    """
  end

  # ── Helpers ─────────────────────────────────────────────

  # The domain sends the raw start instant (DateTime or ISO8601 string); show the
  # wall-clock time it was where the player is.
  @spec format_started(DateTime.t() | String.t() | nil, String.t()) :: String.t() | nil
  defp format_started(%DateTime{} = dt, timezone),
    do: ChatHelpers.format_time(dt, :hh_mm_ss, timezone)

  defp format_started(iso, timezone) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> format_started(dt, timezone)
      _ -> iso
    end
  end

  defp format_started(_, _timezone), do: nil
end
