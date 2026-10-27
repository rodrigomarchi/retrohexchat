defmodule RetroHexChatWeb.Components.UI.RetroGamesPanel do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.Keycap
  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button

  @difficulties ~w(easy normal hard)

  attr :id, :string, required: true
  attr :status, :string, default: "ready"
  attr :selected_game, :map, required: true
  attr :difficulty, :string, default: "normal"
  attr :canvas_ready, :boolean, default: false
  attr :result, Result, default: nil
  attr :record, :map, default: nil, doc: "the `Games.Results.card/1` of the match just written"
  attr :ranked?, :boolean, default: false, doc: "whether this player's matches are written down"
  attr :error_message, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec retro_games_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def retro_games_panel(assigns) do
    ~H"""
    <section id={@id} class={classes(["flex h-full min-h-0 flex-col gap-retro-10", @class])} {@rest}>
      <.game_state
        id={"#{@id}-session"}
        game={@selected_game}
        status={@status}
        difficulty={@difficulty}
        canvas_ready={@canvas_ready}
        result={@result}
        record={@record}
        ranked?={@ranked?}
        error_message={@error_message}
      />
    </section>
    """
  end

  attr :id, :string, required: true
  attr :game, :map, required: true
  attr :status, :string, required: true
  attr :difficulty, :string, required: true
  attr :canvas_ready, :boolean, default: false
  attr :result, Result, default: nil
  attr :record, :map, default: nil
  attr :ranked?, :boolean, default: false
  attr :error_message, :string, default: nil

  defp game_state(assigns) do
    assigns =
      assigns
      |> assign(:difficulties, @difficulties)
      |> assign(:control_rows, control_rows(assigns.game))
      # A one-player game has no opponent: no difficulty, nobody to beat.
      |> assign(:alone, Catalog.solo_only?(assigns.game.id))

    ~H"""
    <div
      id={@id}
      class="flex h-full min-h-0 flex-col"
      data-testid={"retro-game-session-#{@game.id}"}
    >
      <%!-- On a wide screen the game and its panel share the window's height:
            the canvas fits inside it (letterboxed), so neither the bottom of
            the game nor the panel's buttons fall below what the window shows. --%>
      <div class="grid min-h-0 flex-1 auto-rows-max content-start grid-cols-1 gap-retro-10 overflow-auto pr-retro-1 lg:grid-cols-[minmax(0,1fr)_240px] lg:auto-rows-[minmax(0,1fr)] lg:content-stretch lg:overflow-hidden lg:pr-0">
        <div class="flex min-h-0 flex-col">
          <div
            :if={@status in ["ready", "playing"]}
            id={"#{@id}-canvas"}
            phx-hook="RetroGameCanvasHook"
            phx-update="ignore"
            data-game-id={@game.id}
            data-difficulty={@difficulty}
            tabindex="-1"
            class={[
              "relative min-h-[220px] w-full overflow-hidden bg-black p-[2px] shadow-retro-field lg:aspect-auto lg:h-full lg:min-h-0",
              canvas_box_aspect(@game)
            ]}
            data-testid={"retro-game-canvas-#{@game.id}"}
          >
            <canvas width="640" height="480" class="block h-full w-full bg-black object-contain"></canvas>
            <div class="game-canvas__stub absolute inset-0 flex items-center justify-center bg-black text-xs font-bold text-white">
              {dgettext("games", "Loading game...")}
            </div>
          </div>

          <.inset
            :if={@status == "finished"}
            class="flex aspect-[4/3] min-h-[220px] w-full flex-col items-center justify-center gap-retro-8 p-retro-12 text-center lg:aspect-auto lg:h-full lg:min-h-0"
            data-testid="retro-game-result"
          >
            <Icons.game_icon game_id={@game.id} class="h-16 w-16" />
            <h4 class="text-base font-bold">{dgettext("games", "Match Finished")}</h4>
            <p :if={@alone} class="text-sm">
              {dgettext("games", "%{points} points", points: (@result && @result.p1_score) || 0)}
            </p>
            <p :if={not @alone} class="text-sm">
              {dgettext("games", "You %{you} x %{ai} AI",
                you: (@result && @result.p1_score) || 0,
                ai: (@result && @result.p2_score) || 0
              )}
            </p>
            <p
              :if={not @alone and verdict_label(@result)}
              class="text-xs text-muted-foreground"
              data-testid="retro-game-verdict"
            >
              {verdict_label(@result)}
            </p>
            <p
              :if={@result && @result.ended_early?}
              class="text-xs text-muted-foreground"
              data-testid="retro-game-ended-early"
            >
              {dgettext("games", "Ended early")}
            </p>
            <.badge :if={@record && @record.personal_best} variant="success">
              <:icon><Icons.icon_star class="h-3 w-3" /></:icon>
              {dgettext("games", "Personal best")}
            </.badge>
            <%!-- Where the match went, or why it went nowhere: a signed-in
                  player's result is in the game's channel and ranking, and a
                  guest is told what would have put it there. --%>
            <p :if={@record} class="text-xs" data-testid="retro-game-recorded">
              {dgettext("games", "Saved to your record.")}
            </p>
            <p
              :if={not @ranked?}
              class="text-xs text-muted-foreground"
              data-testid="retro-game-unranked"
            >
              {dgettext("games", "Only registered nicknames appear in the ranking.")}
              <.link
                href={Paths.localized("/chat/help/nickserv")}
                target="_blank"
                rel="noopener"
                class="underline"
                data-testid="retro-game-how-to-register"
              >
                {dgettext("games", "How to register")}
              </.link>
            </p>
            <%!-- Everything else about the game — partners, the ranking — is
                  at its home and in its channel. --%>
            <p class="flex flex-wrap justify-center gap-x-retro-8 text-xs">
              <.link
                href={Paths.game_page_path(@game.id)}
                class="underline"
                data-testid="retro-game-home-link"
              >
                {dgettext("share", "Other ways to play")}
              </.link>
              <.link
                href={Paths.chat_path(Catalog.channel_name(@game.id))}
                class="underline"
                data-testid="retro-game-channel-link"
              >
                {Catalog.channel_name(@game.id)}
              </.link>
            </p>
          </.inset>

          <.inset
            :if={@status == "error"}
            class="flex aspect-[4/3] min-h-[220px] w-full flex-col items-center justify-center gap-retro-8 p-retro-12 text-center lg:aspect-auto lg:h-full lg:min-h-0"
            data-testid="retro-game-error"
          >
            <Icons.icon_warning class="h-10 w-10 text-destructive" />
            <h4 class="text-sm font-bold">{dgettext("games", "Could not start this game")}</h4>
            <p class="text-xs text-muted-foreground">{@error_message}</p>
          </.inset>
        </div>

        <aside
          class="flex min-h-0 flex-col gap-retro-8 lg:overflow-y-auto"
          data-testid="retro-game-control-panel"
        >
          <section
            class="order-1 grid gap-retro-6 bg-white p-retro-8 text-xs shadow-retro-field"
            data-testid="retro-game-session-status"
          >
            <div
              class="flex min-w-0 items-center gap-retro-6 border-b border-border pb-retro-6"
              data-testid="retro-game-sidebar-header"
            >
              <Icons.game_icon game_id={@game.id} class="h-7 w-7 shrink-0" />
              <div class="min-w-0">
                <h3 class="truncate text-sm font-bold leading-tight">{@game.name}</h3>
                <p class="truncate text-[11px] text-muted-foreground">{@game.tagline}</p>
              </div>
            </div>
            <div class="flex items-center justify-between gap-retro-6">
              <span class="flex min-w-0 items-center gap-retro-4 font-bold">
                <Icons.icon_robot class="h-4 w-4 shrink-0" />
                {dgettext("games", "Mode")}
              </span>
              <.badge variant="success" class="shrink-0">
                <:icon><Icons.icon_joystick class="h-3 w-3" /></:icon>
                {if @alone, do: dgettext("games", "Solo"), else: dgettext("games", "Solo AI")}
              </.badge>
            </div>
            <dl class="grid gap-retro-4 text-[11px] leading-tight">
              <div class="flex items-center justify-between gap-retro-6">
                <dt class="flex min-w-0 items-center gap-retro-4 text-muted-foreground">
                  <Icons.icon_status_signal class="h-3 w-3 shrink-0" />
                  {dgettext("games", "Status")}
                </dt>
                <dd class="shrink-0 font-bold" data-testid="retro-game-status-label">
                  {status_label(@status)}
                </dd>
              </div>
              <div class="flex items-center justify-between gap-retro-6">
                <dt class="flex min-w-0 items-center gap-retro-4 text-muted-foreground">
                  <Icons.icon_chart_bars class="h-3 w-3 shrink-0" />
                  {dgettext("games", "Goal")}
                </dt>
                <dd class="shrink-0 font-bold">{goal_label(@game)}</dd>
              </div>
            </dl>
          </section>

          <.inset
            :if={not @alone}
            bevel="sunken"
            tone="surface"
            as="section"
            class="order-2 grid gap-retro-6 p-retro-8"
            data-testid="retro-game-difficulty-panel"
          >
            <div class="flex items-center justify-between gap-retro-6">
              <h4 class="flex min-w-0 items-center gap-retro-4 text-xs font-bold">
                <Icons.icon_chart_bars class="h-4 w-4 shrink-0" />
                {dgettext("games", "Difficulty")}
              </h4>
              <span class="flex shrink-0 items-center gap-retro-4 bg-white px-retro-4 py-px text-[11px] font-bold border border-border">
                <.difficulty_icon difficulty={@difficulty} class="h-3.5 w-3.5 shrink-0" />
                {difficulty_label(@difficulty)}
              </span>
            </div>
            <div
              class="grid grid-cols-3 gap-[2px] bg-muted p-[2px] shadow-retro-sunken"
              role="group"
              aria-label={dgettext("games", "Difficulty")}
            >
              <.tool_button
                :for={difficulty <- @difficulties}
                label={difficulty_label(difficulty)}
                size="md"
                active={@difficulty == difficulty}
                pressed={@difficulty == difficulty}
                class="h-8 min-h-0 w-auto min-w-0 gap-retro-4 px-retro-4 text-[11px] font-bold leading-none"
                phx-click="retro_games_set_difficulty"
                phx-value-difficulty={difficulty}
                disabled={@status == "playing"}
                data-testid={"retro-game-difficulty-#{difficulty}"}
              >
                <.difficulty_icon difficulty={difficulty} class="h-4 w-4 shrink-0" />
                <span class="min-w-0 truncate">{difficulty_label(difficulty)}</span>
              </.tool_button>
            </div>
          </.inset>

          <section
            class="order-4 hidden gap-retro-6 bg-white p-retro-8 shadow-retro-field md:grid lg:order-3"
            data-testid="retro-game-controls-panel"
          >
            <h4 class="flex items-center gap-retro-4 text-xs font-bold">
              <Icons.icon_btn_keyboard class="h-4 w-4 shrink-0" />
              {dgettext("games", "Controls")}
            </h4>
            <div
              :for={row <- @control_rows}
              class="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-retro-6 text-[11px]"
            >
              <span class="text-muted-foreground">{row.label}</span>
              <span class="flex min-w-0 flex-wrap gap-retro-4">
                <.keycap :for={key <- row.keys}>{key}</.keycap>
              </span>
            </div>
            <p class="text-[11px] leading-relaxed text-muted-foreground">{@game.controls}</p>
          </section>

          <.inset
            bevel="sunken"
            tone="surface"
            as="section"
            class="order-3 grid grid-cols-[minmax(0,1fr)_112px] gap-retro-4 p-retro-6 lg:order-4 lg:mt-auto lg:grid-cols-1 lg:gap-retro-6 lg:p-retro-8"
            data-testid="retro-game-actions"
          >
            <.button
              :if={@status == "ready" and @canvas_ready}
              size="sm"
              class="h-8 w-full lg:h-10"
              phx-click="retro_games_start_ai"
              data-testid="retro-game-start-ai"
            >
              <:icon><Icons.icon_btn_play class="h-4 w-4" /></:icon>
              {if @alone,
                do: dpgettext("games", "game", "Play"),
                else: dgettext("games", "Play vs AI")}
            </.button>
            <.button
              :if={@status == "ready" and not @canvas_ready}
              size="sm"
              class="h-8 w-full lg:h-10"
              disabled
              data-testid="retro-game-start-disabled"
            >
              <:icon><Icons.icon_btn_play class="h-4 w-4" /></:icon>
              {dgettext("games", "Loading")}
            </.button>
            <.button
              :if={@status == "playing"}
              variant="destructive"
              size="sm"
              class="h-8 w-full lg:h-10"
              phx-click="retro_games_end"
              data-testid="retro-game-end-match"
            >
              <:icon><Icons.icon_btn_disconnect class="h-4 w-4" /></:icon>
              {dgettext("games", "End")}
            </.button>
            <.button
              :if={@status in ["finished", "error"]}
              size="sm"
              class="h-8 w-full lg:h-10"
              phx-click="retro_games_play_again"
              data-testid="retro-game-play-again"
            >
              <:icon><Icons.icon_retry class="h-4 w-4" /></:icon>
              {dgettext("games", "Again")}
            </.button>
          </.inset>
        </aside>
      </div>
    </div>
    """
  end

  defp difficulty_label("easy"), do: dgettext("games", "Easy")
  defp difficulty_label("hard"), do: dgettext("games", "Hard")
  defp difficulty_label(_difficulty), do: dgettext("games", "Normal")

  @doc """
  What a match of `game` plays to, as the library panel states it. Every game
  in the catalogue has its own clause: a game without one raises instead of
  being shown another game's goal.
  """
  @spec goal_label(%{required(:id) => String.t(), optional(atom()) => term()}) :: String.t()
  def goal_label(%{id: "hex_pong"}), do: dgettext("games", "First to 11")
  def goal_label(%{id: "light_trails"}), do: dgettext("games", "First to 3 games")
  def goal_label(%{id: "pixel_tanks"}), do: dgettext("games", "Best of 3 rounds")
  def goal_label(%{id: "star_duel"}), do: dgettext("games", "First to 7")
  def goal_label(%{id: "gravity_well"}), do: dgettext("games", "First to 7")
  def goal_label(%{id: "debris_field"}), do: dgettext("games", "First to 7")
  def goal_label(%{id: "block_breakers"}), do: dgettext("games", "Clear all blocks")
  def goal_label(%{id: "hex_warlords"}), do: dgettext("games", "Last king standing")
  def goal_label(%{id: "hex_raid_blitz"}), do: dgettext("games", "5 sections")
  def goal_label(%{id: "hex_raid"}), do: dgettext("games", "10 sections")
  def goal_label(%{id: "hex_raid_pacifist"}), do: dgettext("games", "10 sections")
  def goal_label(%{id: "hex_boxing"}), do: dgettext("games", "Best of 3 rounds")
  def goal_label(%{id: "hex_outlaw"}), do: dgettext("games", "Best of 3 rounds")
  def goal_label(%{id: "hex_outlaw_ricochet"}), do: dgettext("games", "Best of 3 rounds")
  def goal_label(%{id: "hex_outlaw_stagecoach"}), do: dgettext("games", "Best of 3 rounds")
  def goal_label(%{id: "hex_outlaw_nml"}), do: dgettext("games", "Best of 3 rounds")
  def goal_label(%{id: "hex_invaders"}), do: dgettext("games", "10 waves")
  def goal_label(%{id: "hex_invaders_coop"}), do: dgettext("games", "10 waves")
  def goal_label(%{id: "hex_invaders_blitz"}), do: dgettext("games", "5 waves")
  def goal_label(%{id: "hex_enduro"}), do: dgettext("games", "Best of 3 days")
  def goal_label(%{id: "hex_enduro_night"}), do: dgettext("games", "3 minutes")
  def goal_label(%{id: "hex_enduro_sprint"}), do: dgettext("games", "90 seconds")
  def goal_label(%{id: "hex_tennis_quick"}), do: dgettext("games", "First to 3 games")
  def goal_label(%{id: "hex_tennis"}), do: dgettext("games", "First to 6 games")
  def goal_label(%{id: "hex_tennis_sudden"}), do: dgettext("games", "First to 6 games")
  def goal_label(%{id: "hex_skiing"}), do: dgettext("games", "Best of 3 runs")
  def goal_label(%{id: "hex_skiing_escape"}), do: dgettext("games", "Last standing")
  def goal_label(%{id: "hex_skiing_clean"}), do: dgettext("games", "Fastest time")
  def goal_label(%{id: "hex_frost"}), do: dgettext("games", "Best of 5 rounds")
  def goal_label(%{id: "hex_frost_blizzard"}), do: dgettext("games", "1 round")
  def goal_label(%{id: "hex_frost_peaceful"}), do: dgettext("games", "Build first")
  def goal_label(%{id: "hex_hockey"}), do: dgettext("games", "3 periods")
  def goal_label(%{id: "hex_hockey_blitz"}), do: dgettext("games", "1 period")
  def goal_label(%{id: "hex_hockey_showdown"}), do: dgettext("games", "First to 5 goals")
  def goal_label(%{id: "hex_jungle"}), do: dgettext("games", "32 treasures in 20 minutes")

  def goal_label(%{id: id}) when id in ~w(hex_solitaire hex_solitaire_draw3),
    do: dgettext("games", "Four piles, ace to king")

  # A card table stands up on a phone held upright: the game lays itself out
  # on the box it is given (`view` in its definition), so on a narrow screen
  # the box is tall and the cards are as big as the phone allows.
  defp canvas_box_aspect(%{id: id}) when id in ~w(hex_solitaire hex_solitaire_draw3),
    do: "aspect-[464/720] sm:aspect-[4/3]"

  defp canvas_box_aspect(_game), do: "aspect-[4/3]"

  @doc """
  The keys of `game`, one row per action, as the library panel lists them.
  Every game in the catalogue has its own clause: a game without one raises
  instead of being shown another game's keys.
  """
  @spec control_rows(%{required(:id) => String.t(), optional(atom()) => term()}) :: [
          %{label: String.t(), keys: [String.t()]}
        ]
  def control_rows(%{id: "hex_jungle"}) do
    [
      %{label: dgettext("games", "Move"), keys: ["←", "→", "A", "D"]},
      %{label: dgettext("games", "Jump"), keys: ["Space"]},
      %{label: dgettext("games", "Climb"), keys: ["↑", "↓", "W", "S"]},
      %{label: dgettext("games", "Let go of the vine"), keys: ["↓", "S"]}
    ]
  end

  # Played with the mouse or a finger: the "keys" are the gestures.
  def control_rows(%{id: id}) when id in ~w(hex_solitaire hex_solitaire_draw3) do
    [
      %{label: dgettext("games", "Move a card to its place"), keys: [dgettext("games", "Tap")]},
      %{label: dgettext("games", "Move cards between piles"), keys: [dgettext("games", "Drag")]},
      %{label: dgettext("games", "Draw from the deck"), keys: [dgettext("games", "Tap the deck")]}
    ]
  end

  def control_rows(%{id: "hex_pong"}) do
    [
      %{label: dgettext("games", "Move"), keys: ["↑", "↓", "W", "S"]}
    ]
  end

  def control_rows(%{id: "light_trails"}) do
    [
      %{label: dgettext("games", "Steer"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]}
    ]
  end

  def control_rows(%{id: "pixel_tanks"}) do
    [
      %{label: dgettext("games", "Rotate"), keys: ["←", "→", "A", "D"]},
      %{label: dgettext("games", "Forward"), keys: ["↑", "W"]},
      %{label: dgettext("games", "Fire"), keys: ["Space", "Shift"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "star_duel",
             "gravity_well",
             "debris_field"
           ] do
    [
      %{label: dgettext("games", "Rotate"), keys: ["←", "→", "A", "D"]},
      %{label: dgettext("games", "Thrust"), keys: ["↑", "W"]},
      %{label: dgettext("games", "Fire/Warp"), keys: ["Space", "↓", "S"]}
    ]
  end

  def control_rows(%{id: "block_breakers"}) do
    [
      %{label: dgettext("games", "Move"), keys: ["←", "→", "A", "D"]}
    ]
  end

  def control_rows(%{id: "hex_warlords"}) do
    [
      %{label: dgettext("games", "Shield"), keys: ["↑", "↓", "W", "S"]},
      %{label: dgettext("games", "Catch/Release"), keys: ["Space"]}
    ]
  end

  def control_rows(%{id: "hex_raid_pacifist"}) do
    [
      %{label: dgettext("games", "Move/Speed"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Fire"), keys: ["Space"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "hex_raid",
             "hex_raid_blitz"
           ] do
    [
      %{label: dgettext("games", "Move/Speed"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Fire/Mine"), keys: ["Space", "Shift"]}
    ]
  end

  def control_rows(%{id: "hex_boxing"}) do
    [
      %{label: dgettext("games", "Move"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Punch"), keys: ["Space", "Shift"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "hex_outlaw",
             "hex_outlaw_ricochet",
             "hex_outlaw_stagecoach",
             "hex_outlaw_nml"
           ] do
    [
      %{label: dgettext("games", "Move/Aim"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Fire"), keys: ["Space", "Shift"]}
    ]
  end

  # ex_dna:disable-for-next-line each game's own control labels
  def control_rows(%{id: id})
      when id in [
             "hex_tennis",
             "hex_tennis_quick",
             "hex_tennis_sudden"
           ] do
    [
      %{label: dgettext("games", "Move"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Serve"), keys: ["Space", "Shift"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "hex_invaders",
             "hex_invaders_coop",
             "hex_invaders_blitz"
           ] do
    [
      %{label: dgettext("games", "Move"), keys: ["←", "→", "A", "D"]},
      %{label: dgettext("games", "Fire"), keys: ["Space"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "hex_enduro",
             "hex_enduro_night",
             "hex_enduro_sprint"
           ] do
    [
      %{label: dgettext("games", "Lane"), keys: ["←", "→", "A", "D"]},
      %{label: dgettext("games", "Speed"), keys: ["↑", "↓", "W", "S"]},
      %{label: dgettext("games", "Turbo"), keys: ["Space", "Shift"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "hex_skiing",
             "hex_skiing_escape",
             "hex_skiing_clean"
           ] do
    [
      %{label: dgettext("games", "Steer"), keys: ["←", "→", "A", "D"]}
    ]
  end

  def control_rows(%{id: id})
      when id in [
             "hex_frost",
             "hex_frost_blizzard",
             "hex_frost_peaceful"
           ] do
    [
      %{label: dgettext("games", "Move"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Jump rows"), keys: ["↑", "↓", "W", "S"]}
    ]
  end

  # ex_dna:disable-for-next-line each game's own control labels
  def control_rows(%{id: id})
      when id in [
             "hex_hockey",
             "hex_hockey_blitz",
             "hex_hockey_showdown"
           ] do
    [
      %{label: dgettext("games", "Move"), keys: ["↑", "↓", "←", "→", "W", "A", "S", "D"]},
      %{label: dgettext("games", "Shoot/Tackle"), keys: ["Space", "Shift"]}
    ]
  end

  attr :difficulty, :string, required: true
  attr :class, :string, default: nil

  defp difficulty_icon(assigns) do
    ~H"""
    <Icons.icon_shield :if={@difficulty == "easy"} class={@class} />
    <Icons.icon_joystick :if={@difficulty == "normal"} class={@class} />
    <Icons.icon_sword :if={@difficulty == "hard"} class={@class} />
    """
  end

  defp status_label("ready"), do: dgettext("games", "Ready")
  defp status_label("playing"), do: dgettext("games", "Playing")
  defp status_label("finished"), do: dgettext("games", "Finished")
  defp status_label("error"), do: dgettext("games", "Error")
  defp status_label(_status), do: dgettext("games", "Loading")

  # A match ended early names nobody, whoever led: it says only that it ended early.
  defp verdict_label(%Result{ended_early?: true}), do: nil
  defp verdict_label(%Result{outcome: :p1}), do: dgettext("games", "You won")
  defp verdict_label(%Result{outcome: :p2}), do: dgettext("games", "AI won")
  defp verdict_label(%Result{outcome: :draw}), do: dgettext("games", "Draw")
  defp verdict_label(%Result{outcome: :coop_win}), do: dgettext("games", "Board cleared")
  defp verdict_label(%Result{outcome: :coop_loss}), do: dgettext("games", "Out of lives")
  defp verdict_label(_unknown), do: dgettext("games", "No winner reported")
end
