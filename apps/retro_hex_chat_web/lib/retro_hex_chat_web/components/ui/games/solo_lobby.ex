defmodule RetroHexChatWeb.Components.UI.SoloLobby do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Window

  @doc """
  Renders a multi-state solo arcade lobby with game picker, preview, playing, and finished states.

  Composed entirely from platform primitives (Window, Button, Badge, Icons).
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :nickname, :string, required: true
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
  attr :on_close, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec solo_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def solo_lobby(assigns) do
    ~H"""
    <div :if={@show} id={@id} class={@class} {@rest}>
      <.window class={[
        "max-w-full",
        if(@session_status == "lobby" && @previewed_game,
          do: "w-full md:w-[1100px]",
          else: "w-full md:w-[1050px]"
        )
      ]}>
        <.window_title_bar
          title={gettext("Arcade — %{nickname}", nickname: @nickname)}
          controls={[:close]}
          on_close={@on_close}
        >
          <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
        </.window_title_bar>

        <.window_body class="p-retro-16 space-y-retro-12">
          <%!-- Inactivity warning --%>
          <div
            :if={@inactivity_warning}
            class="flex items-center gap-retro-4 shadow-retro-field bg-warning-light px-retro-8 py-retro-4 text-xs"
          >
            <Icons.icon_warning class="w-4 h-4 flex-shrink-0" />
            <span>
              {gettext(
                "Session will be closed due to inactivity soon. Select a game to keep it active."
              )}
            </span>
          </div>

          <.lobby_picker
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
            on_close={@on_close}
          />

          <.finished_state
            :if={@session_status == "finished"}
            game_name={@game_name}
            game_id={@game_id}
            game_duration={@game_duration}
            on_close={@on_close}
          />
        </.window_body>
      </.window>
    </div>
    """
  end

  # ── Lobby: Game Picker ──────────────────────────────────

  attr :games, :list, required: true
  attr :on_preview_game, :any, default: nil
  attr :on_close, :any, default: nil

  defp lobby_picker(assigns) do
    ~H"""
    <div class="space-y-retro-12">
      <%!-- Header --%>
      <div class="flex items-center gap-retro-12">
        <Icons.icon_game_arcade class="w-8 h-8 flex-shrink-0" />
        <div>
          <p class="text-sm font-bold">{gettext("Retro Arcade")}</p>
          <p class="text-xs text-muted-foreground">
            {gettext("Classic games running in your browser via WebAssembly")}
          </p>
        </div>
      </div>

      <%!-- Game grid --%>
      <div>
        <p class="text-xs font-bold mb-retro-4">{gettext("Choose a game:")}</p>
        <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-retro-8">
          <button
            :for={game <- @games}
            type="button"
            phx-click={@on_preview_game}
            phx-value-game-id={game.id}
            title={game.description}
            class={[
              "flex flex-col items-center gap-retro-4",
              "shadow-retro-field bg-white p-retro-8 text-center cursor-pointer",
              "hover:bg-hover-bg active:shadow-retro-sunken"
            ]}
            data-testid={"solo-game-#{game.id}"}
          >
            <Icons.game_icon game_id={game.id} class="w-12 h-12 shrink-0" />
            <span class="text-xs font-bold leading-tight">{game.name}</span>
            <span class="text-[10px] text-muted-foreground leading-tight">
              {Map.get(game, :tagline, game.description)}
            </span>
          </button>
        </div>
      </div>

      <%!-- Footer --%>
      <div>
        <.button variant="outline" phx-click={@on_close}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {gettext("Leave")}
        </.button>
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
    <div class="space-y-retro-12">
      <%!-- Header: icon + info + action buttons --%>
      <div class="flex items-center gap-retro-12">
        <Icons.game_icon game_id={@previewed_game.id} class="w-8 h-8 flex-shrink-0" />
        <div class="flex-1 min-w-0 space-y-retro-2">
          <h3 class="text-sm font-bold">{@previewed_game.name}</h3>
          <p class="text-xs text-muted-foreground">{@previewed_game.description}</p>
          <.badge variant="secondary">
            {gettext("%{engine} Engine", engine: String.upcase(to_string(@previewed_game.engine)))}
          </.badge>
        </div>
        <div class="flex gap-retro-6 flex-shrink-0">
          <.button variant="outline" size="sm" phx-click={@on_back}>
            <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
            {gettext("Back")}
          </.button>
          <.button
            size="sm"
            class="font-bold"
            phx-click={@on_select_game}
            phx-value-game-id={@previewed_game.id}
            data-testid={"solo-game-start-#{@previewed_game.id}"}
          >
            <:icon><Icons.icon_btn_join class="w-4 h-4" /></:icon>
            {gettext("Start Game")}
          </.button>
          <.button variant="outline" size="sm" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {gettext("Leave")}
          </.button>
        </div>
      </div>

      <%!-- Detail sections — 3-column grid --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-retro-12 min-h-0">
        <%!-- About --%>
        <fieldset
          :if={@previewed_game[:about] && @previewed_game.about != []}
          class="retro-fieldset p-retro-8 min-w-0"
        >
          <legend class="text-xs font-bold px-retro-4">{gettext("About")}</legend>
          <p
            :for={paragraph <- @previewed_game.about}
            class="text-xs mb-retro-6 last:mb-0 leading-relaxed"
          >
            {paragraph}
          </p>
        </fieldset>

        <%!-- Controls --%>
        <fieldset
          :if={@previewed_game[:controls] && @previewed_game.controls != []}
          class="retro-fieldset p-retro-8 min-w-0"
        >
          <legend class="text-xs font-bold px-retro-4">{gettext("Keyboard Controls")}</legend>
          <table class="w-full text-xs">
            <thead>
              <tr>
                <th class="text-left py-retro-2 pr-retro-6 font-bold border-b border-gray-400">
                  {gettext("Key")}
                </th>
                <th class="text-left py-retro-2 font-bold border-b border-gray-400">
                  {gettext("Action")}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{key, action} <- @previewed_game.controls}>
                <td class="py-retro-2 pr-retro-6 whitespace-nowrap">
                  <kbd class="shadow-retro-raised bg-surface px-retro-4 text-xs font-mono">{key}</kbd>
                </td>
                <td class="py-retro-2">{action}</td>
              </tr>
            </tbody>
          </table>
        </fieldset>

        <%!-- Tips --%>
        <fieldset
          :if={@previewed_game[:tips] && @previewed_game.tips != []}
          class="retro-fieldset p-retro-8 min-w-0"
        >
          <legend class="text-xs font-bold px-retro-4">{gettext("Tips")}</legend>
          <ul class="list-disc pl-retro-16 text-xs space-y-retro-4 leading-relaxed">
            <li :for={tip <- @previewed_game.tips}>{tip}</li>
          </ul>
        </fieldset>
      </div>
    </div>
    """
  end

  # ── Playing State ───────────────────────────────────────

  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_started_at, :string, default: nil
  attr :on_close, :any, default: nil

  defp playing_state(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-12">
      <Icons.game_icon game_id={@game_id} class="w-8 h-8 flex-shrink-0" />
      <div class="flex-1 space-y-retro-2">
        <h3 class="text-sm font-bold">{@game_name}</h3>
        <p class="text-xs text-muted-foreground">{gettext("Game in progress...")}</p>
        <p :if={@game_started_at} class="text-xs font-mono">
          {gettext("Started: %{started_at}", started_at: @game_started_at)}
        </p>
      </div>
      <.button
        variant="outline"
        size="sm"
        class="flex-shrink-0"
        phx-click={@on_close}
        data-testid="solo-session-end"
      >
        <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
        {gettext("End Session")}
      </.button>
    </div>
    """
  end

  # ── Finished State ──────────────────────────────────────

  attr :game_name, :string, required: true
  attr :game_id, :string, required: true
  attr :game_duration, :integer, default: nil
  attr :on_close, :any, default: nil

  defp finished_state(assigns) do
    ~H"""
    <div class="space-y-retro-8">
      <%!-- Game header --%>
      <div class="flex items-center gap-retro-10">
        <Icons.game_icon game_id={@game_id} class="w-8 h-8 flex-shrink-0" />
        <h3 class="text-sm font-bold">{@game_name}</h3>
      </div>

      <hr class="border-t border-gray-400" />

      <%!-- Summary --%>
      <div class="space-y-retro-6">
        <div class="flex items-center gap-retro-6 text-xs">
          <Icons.icon_checkmark class="w-4 h-4 flex-shrink-0" />
          <span>{gettext("Session Complete")}</span>
        </div>
        <div :if={@game_duration} class="flex items-center gap-retro-6 text-xs">
          <Icons.icon_clock class="w-4 h-4 flex-shrink-0" />
          <span>
            {gettext("Play time:")} <strong>{format_duration(@game_duration)}</strong>
          </span>
        </div>
      </div>

      <hr class="border-t border-gray-400" />

      <%!-- Close button --%>
      <div>
        <.button variant="outline" phx-click={@on_close} data-testid="solo-session-close">
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {gettext("Close")}
        </.button>
      </div>
    </div>
    """
  end

  # ── Helpers ─────────────────────────────────────────────

  @spec format_duration(integer()) :: String.t()
  defp format_duration(seconds) when seconds < 60,
    do: gettext("%{seconds}s", seconds: seconds)

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes >= 60 do
      hours = div(minutes, 60)
      mins = rem(minutes, 60)
      gettext("%{hours}h %{minutes}m %{seconds}s", hours: hours, minutes: mins, seconds: secs)
    else
      gettext("%{minutes}m %{seconds}s", minutes: minutes, seconds: secs)
    end
  end
end
