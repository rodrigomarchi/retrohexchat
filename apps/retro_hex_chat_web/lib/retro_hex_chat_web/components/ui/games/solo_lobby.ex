defmodule RetroHexChatWeb.Components.UI.SoloLobby do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button

  @doc """
  Renders the multi-state body of the solo arcade window: the game launcher,
  preview, playing and finished states.

  The window chrome (title bar, close control) is supplied by the enclosing
  `desktop_window` — this component renders only the body content. Composed from
  platform primitives (Button, Badge, Icons).
  """
  attr :id, :string, required: true
  attr :games, :list, required: true
  attr :session_status, :string, default: "lobby"
  attr :previewed_game, :map, default: nil
  attr :game_name, :string, default: nil
  attr :game_id, :string, default: nil
  attr :game_started_at, :string, default: nil
  attr :game_duration, :integer, default: nil
  attr :inactivity_warning, :boolean, default: false
  attr :on_preview_game, :any, default: nil
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
        class="shadow-retro-field flex shrink-0 items-center gap-retro-4 bg-warning-light px-retro-8 py-retro-4 text-xs"
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
        games={@games}
        on_preview_game={@on_preview_game}
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

  attr :games, :list, required: true
  attr :on_preview_game, :any, default: nil
  attr :on_close, :any, default: nil

  defp lobby_launcher(assigns) do
    ~H"""
    <div data-testid="arcade-library" class="flex min-h-0 flex-1 flex-col gap-retro-8">
      <div class="flex items-center gap-retro-12">
        <Icons.icon_game_arcade class="h-8 w-8 flex-shrink-0" />
        <div class="min-w-0">
          <p class="text-sm font-bold">{dgettext("games", "Retro Arcade")}</p>
          <p class="text-xs text-muted-foreground">
            {dgettext("games", "Classic games running in your browser via WebAssembly")}
          </p>
        </div>
      </div>

      <div
        data-testid="arcade-icon-window"
        class="min-h-0 flex-1 overflow-auto bg-white p-retro-10 shadow-retro-field"
      >
        <div
          data-testid="arcade-icon-grid"
          class="grid grid-cols-[repeat(auto-fill,minmax(92px,1fr))] content-start gap-x-retro-8 gap-y-retro-12"
        >
          <button
            :for={game <- @games}
            type="button"
            phx-click={@on_preview_game}
            phx-value-game-id={game.id}
            title={game.description}
            aria-label={game.name}
            class={[
              "group flex min-h-[88px] flex-col items-center justify-start gap-retro-4 px-retro-4 py-retro-6 text-center",
              "cursor-pointer hover:bg-hover-bg focus:outline-none focus:shadow-retro-focus active:shadow-retro-sunken"
            ]}
            data-testid={"arcade-game-#{game.id}"}
          >
            <span class="grid h-12 w-12 place-items-center">
              <Icons.game_icon game_id={game.id} class="h-12 w-12 shrink-0" />
            </span>
            <span class="max-w-full text-[11px] font-bold leading-tight [overflow-wrap:anywhere]">
              {game.name}
            </span>
          </button>
        </div>
      </div>

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

  # ── Lobby: Game Preview ─────────────────────────────────

  attr :previewed_game, :map, required: true
  attr :on_select_game, :any, default: nil
  attr :on_back, :any, default: nil
  attr :on_close, :any, default: nil

  defp lobby_preview(assigns) do
    ~H"""
    <div
      data-testid="arcade-game-preview"
      class="flex min-h-0 flex-1 flex-col gap-retro-10"
    >
      <div class="flex shrink-0 items-center gap-retro-12 bg-white p-retro-10 shadow-retro-field">
        <Icons.game_icon game_id={@previewed_game.id} class="h-12 w-12 flex-shrink-0" />
        <div class="min-w-0 flex-1 space-y-retro-2">
          <h3 class="truncate text-base font-bold leading-tight">{@previewed_game.name}</h3>
          <p class="text-xs leading-snug text-muted-foreground">{@previewed_game.description}</p>
          <.badge variant="secondary">
            {dgettext("games", "%{engine} Engine",
              engine: String.upcase(to_string(@previewed_game.engine))
            )}
          </.badge>
        </div>
        <div class="flex shrink-0 flex-wrap justify-end gap-retro-6">
          <.button
            variant="outline"
            size="sm"
            phx-click={@on_back}
            data-testid="arcade-preview-back"
          >
            <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
            {dgettext("games", "Back")}
          </.button>
          <.button
            size="sm"
            class="font-bold"
            phx-click={@on_select_game}
            phx-value-game-id={@previewed_game.id}
            data-testid={"solo-game-start-#{@previewed_game.id}"}
          >
            <:icon><Icons.icon_btn_join class="w-4 h-4" /></:icon>
            {dgettext("games", "Start Game")}
          </.button>
          <.button variant="outline" size="sm" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("games", "Leave")}
          </.button>
        </div>
      </div>

      <div class="retro-scrollbar min-h-0 flex-1 overflow-auto bg-white p-retro-10 shadow-retro-sunken">
        <div class="grid min-h-full grid-cols-1 items-stretch gap-retro-10 md:grid-cols-[repeat(auto-fit,minmax(18rem,1fr))]">
          <fieldset
            :if={@previewed_game[:about] && @previewed_game.about != []}
            class="retro-fieldset min-h-[160px] min-w-0 p-retro-8"
          >
            <legend class="px-retro-4 text-xs font-bold">{dgettext("games", "About")}</legend>
            <div class="pr-retro-4">
              <p
                :for={paragraph <- @previewed_game.about}
                class="mb-retro-6 text-xs leading-relaxed last:mb-0"
              >
                {paragraph}
              </p>
            </div>
          </fieldset>

          <fieldset
            :if={@previewed_game[:controls] && @previewed_game.controls != []}
            class="retro-fieldset min-h-[160px] min-w-0 p-retro-8"
          >
            <legend class="px-retro-4 text-xs font-bold">
              {dgettext("games", "Keyboard Controls")}
            </legend>
            <div class="pr-retro-2">
              <table class="w-full text-[11px] leading-snug">
                <thead>
                  <tr>
                    <th class="w-[7.75rem] border-b border-gray-400 py-retro-2 pr-retro-6 text-left font-bold">
                      {dgettext("games", "Key")}
                    </th>
                    <th class="border-b border-gray-400 py-retro-2 text-left font-bold">
                      {dgettext("games", "Action")}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{key, action} <- @previewed_game.controls}>
                    <td class="w-[7.75rem] whitespace-nowrap py-retro-2 pr-retro-6 align-top">
                      <kbd class="shadow-retro-raised bg-surface px-retro-4 font-mono text-[11px]">
                        {key}
                      </kbd>
                    </td>
                    <td class="py-retro-2 align-top">{action}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </fieldset>

          <fieldset
            :if={@previewed_game[:tips] && @previewed_game.tips != []}
            class="retro-fieldset min-h-[160px] min-w-0 p-retro-8"
          >
            <legend class="px-retro-4 text-xs font-bold">{dgettext("games", "Tips")}</legend>
            <div class="pr-retro-4">
              <ul class="list-disc space-y-retro-4 pl-retro-16 text-xs leading-relaxed">
                <li :for={tip <- @previewed_game.tips}>{tip}</li>
              </ul>
            </div>
          </fieldset>
        </div>
      </div>
    </div>
    """
  end

  # ── Playing State ───────────────────────────────────────

  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_started_at, :string, default: nil
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
          {dgettext("games", "Started %{time}", time: format_started(@game_started_at))}
        </p>
      </div>

      <div class="flex items-start gap-retro-8 shadow-retro-field bg-white px-retro-12 py-retro-8 text-xs max-w-sm text-left">
        <Icons.icon_btn_open class="w-4 h-4 flex-shrink-0 mt-[1px]" />
        <span>
          {dgettext(
            "games",
            "The game runs in a separate window. Keep this window open to track your session — closing the game window ends it."
          )}
        </span>
      </div>

      <div class="flex flex-wrap items-center justify-center gap-retro-8">
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
            {dgettext("games", "Play time:")} <strong>{format_duration(@game_duration)}</strong>
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

  # The domain sends the raw start instant (DateTime or ISO8601 string); show a
  # readable wall-clock time rather than the full microsecond ISO timestamp.
  @spec format_started(DateTime.t() | String.t() | nil) :: String.t() | nil
  defp format_started(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp format_started(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> iso
    end
  end

  defp format_started(_), do: nil

  @spec format_duration(integer()) :: String.t()
  defp format_duration(seconds) when seconds < 60,
    do: dgettext("games", "%{seconds}s", seconds: seconds)

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes >= 60 do
      hours = div(minutes, 60)
      mins = rem(minutes, 60)

      dgettext("games", "%{hours}h %{minutes}m %{seconds}s",
        hours: hours,
        minutes: mins,
        seconds: secs
      )
    else
      dgettext("games", "%{minutes}m %{seconds}s", minutes: minutes, seconds: secs)
    end
  end
end
