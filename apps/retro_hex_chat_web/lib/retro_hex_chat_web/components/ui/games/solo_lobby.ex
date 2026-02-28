defmodule RetroHexChatWeb.Components.UI.SoloLobby do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Window

  @doc """
  Renders a multi-state solo arcade lobby with game picker, preview, playing, and finished states.

  Based on the platform SoloLobby component with the same visual style but using
  the showcase UI design system components (Window, Badge).
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
      <.window>
        <.window_title_bar title={"Arcade — #{@nickname}"} controls={[:close]}>
          <:icon>
            <Icons.icon_joystick class="w-[16px] h-[16px]" />
          </:icon>
        </.window_title_bar>
        <.window_body>
          <%!-- Inactivity warning overlay --%>
          <div
            :if={@inactivity_warning}
            class="shadow-retro-raised bg-warning-bg p-2 mb-2 text-xs text-center"
          >
            <Icons.icon_warning class="w-[16px] h-[16px] inline-block mr-1" />
            Session will be closed due to inactivity soon. Select a game to keep it active.
          </div>

          <%!-- State: Lobby (no preview) --%>
          <.lobby_picker
            :if={@session_status == "lobby" && !@previewed_game}
            games={@games}
            on_preview_game={@on_preview_game}
            on_close={@on_close}
          />

          <%!-- State: Lobby (with preview) --%>
          <.lobby_preview
            :if={@session_status == "lobby" && @previewed_game}
            previewed_game={@previewed_game}
            on_select_game={@on_select_game}
            on_back={@on_back}
            on_close={@on_close}
          />

          <%!-- State: Playing --%>
          <.playing_state
            :if={@session_status == "playing"}
            game_name={@game_name}
            game_id={@game_id}
            game_started_at={@game_started_at}
            on_close={@on_close}
          />

          <%!-- State: Finished --%>
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
    <div>
      <%!-- Header --%>
      <div class="flex items-center gap-2 mb-3">
        <Icons.icon_game_arcade class="w-[32px] h-[32px] flex-shrink-0" />
        <div>
          <p class="text-sm font-bold">Retro Arcade</p>
          <p class="text-xs text-muted-foreground">
            Classic games running in your browser via WebAssembly
          </p>
        </div>
      </div>

      <%!-- Game grid --%>
      <p class="text-sm font-bold mb-2">Choose a game:</p>
      <div class="grid grid-cols-3 gap-2">
        <.button
          :for={game <- @games}
          type="button"
          variant="ghost"
          class={[
            "shadow-retro-field bg-white p-2 text-center cursor-pointer h-auto",
            "hover:bg-hover-bg active:shadow-retro-sunken flex-col"
          ]}
          phx-click={@on_preview_game}
          phx-value-game-id={game.id}
          title={game.name}
        >
          <div class="w-[32px] h-[32px] mx-auto mb-1 bg-gray-200 shadow-retro-field flex items-center justify-center">
            <span class="text-xs font-mono text-gray-500">ico</span>
          </div>
          <p class="text-xs font-bold truncate">{game.name}</p>
        </.button>
      </div>

      <%!-- Footer --%>
      <div class="mt-3">
        <.button variant="outline" phx-click={@on_close}>
          Leave
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
    <div>
      <%!-- Header with game info --%>
      <div class="flex items-start gap-3 mb-3">
        <div class="w-[32px] h-[32px] flex-shrink-0 bg-gray-200 shadow-retro-field flex items-center justify-center">
          <span class="text-xs font-mono text-gray-500">ico</span>
        </div>
        <div class="flex-1 min-w-0">
          <h3 class="text-sm font-bold">{@previewed_game.name}</h3>
          <p class="text-xs text-muted-foreground">{@previewed_game.tagline}</p>
          <.badge variant="secondary" class="mt-1">{@previewed_game.engine}</.badge>
        </div>
      </div>

      <%!-- Action buttons --%>
      <div class="flex gap-2 mb-3">
        <.button variant="outline" size="sm" phx-click={@on_back}>
          Back
        </.button>
        <.button
          size="sm"
          class="font-bold"
          phx-click={@on_select_game}
          phx-value-game-id={@previewed_game.id}
        >
          Start Game
        </.button>
      </div>

      <%!-- Detail sections --%>
      <div class="space-y-2">
        <%!-- About --%>
        <fieldset :if={@previewed_game[:about]} class="shadow-retro-field p-2">
          <legend class="text-xs font-bold px-1">About</legend>
          <p class="text-xs">{@previewed_game.about}</p>
        </fieldset>

        <%!-- Controls --%>
        <fieldset
          :if={@previewed_game[:controls] && @previewed_game.controls != []}
          class="shadow-retro-field p-2"
        >
          <legend class="text-xs font-bold px-1">Keyboard Controls</legend>
          <table class="w-full text-xs">
            <thead>
              <tr>
                <th class="text-left py-1 pr-2 font-bold">Key</th>
                <th class="text-left py-1 font-bold">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{key, action} <- @previewed_game.controls}>
                <td class="py-[2px] pr-2">
                  <kbd class="shadow-retro-raised bg-surface px-1 text-xs font-mono">{key}</kbd>
                </td>
                <td class="py-[2px]">{action}</td>
              </tr>
            </tbody>
          </table>
        </fieldset>

        <%!-- Tips --%>
        <fieldset
          :if={@previewed_game[:tips] && @previewed_game.tips != []}
          class="shadow-retro-field p-2"
        >
          <legend class="text-xs font-bold px-1">Tips</legend>
          <ul class="list-disc list-inside text-xs space-y-1">
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
    <div class="flex items-center gap-3">
      <div class="w-[32px] h-[32px] flex-shrink-0 bg-gray-200 shadow-retro-field flex items-center justify-center">
        <span class="text-xs font-mono text-gray-500">ico</span>
      </div>
      <div class="flex-1">
        <h3 class="text-sm font-bold">{@game_name}</h3>
        <p class="text-xs text-muted-foreground">Game in progress...</p>
        <p
          :if={@game_started_at}
          class="text-xs font-mono mt-1"
        >
          Started: {@game_started_at}
        </p>
      </div>
      <.button variant="outline" size="sm" class="flex-shrink-0" phx-click={@on_close}>
        End Session
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
    <div>
      <%!-- Game header --%>
      <div class="flex items-center gap-3 mb-3">
        <div class="w-[32px] h-[32px] flex-shrink-0 bg-gray-200 shadow-retro-field flex items-center justify-center">
          <span class="text-xs font-mono text-gray-500">ico</span>
        </div>
        <div>
          <h3 class="text-sm font-bold">{@game_name}</h3>
        </div>
      </div>

      <hr class="border-t border-gray-400 my-2" />

      <%!-- Summary --%>
      <div class="space-y-1 mb-3">
        <div class="flex items-center gap-2 text-xs">
          <Icons.icon_checkmark class="w-[16px] h-[16px] flex-shrink-0" />
          <span>Session Complete</span>
        </div>
        <div :if={@game_duration} class="flex items-center gap-2 text-xs">
          <Icons.icon_clock class="w-[16px] h-[16px] flex-shrink-0" />
          <span>Play time: <strong>{format_duration(@game_duration)}</strong></span>
        </div>
      </div>

      <hr class="border-t border-gray-400 my-2" />

      <%!-- Close button --%>
      <div>
        <.button variant="outline" phx-click={@on_close}>
          Close
        </.button>
      </div>
    </div>
    """
  end

  # ── Helpers ─────────────────────────────────────────────

  @spec format_duration(integer()) :: String.t()
  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes >= 60 do
      hours = div(minutes, 60)
      mins = rem(minutes, 60)
      "#{hours}h #{mins}m #{secs}s"
    else
      "#{minutes}m #{secs}s"
    end
  end
end
