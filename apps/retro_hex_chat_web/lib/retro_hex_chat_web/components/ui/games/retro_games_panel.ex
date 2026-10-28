defmodule RetroHexChatWeb.Components.UI.RetroGamesPanel do
  @moduledoc """
  A Retro Game against the computer, or alone: the game's stage
  (`Games.GameStage`) with the canvas filling it, and the menu over it in
  each state of a match — what to play and how before it (`ready`), held
  while it runs (`playing`, opened with Esc or the corner key), how it ended
  (`finished`), or why it could not start (`error`).

  The page decides when the menu is open; the ready menu's `:invite` slot is
  where it puts what only it can offer (a partner, a link).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Games.ArcadeIcon
  import RetroHexChatWeb.Components.UI.Games.GameStage
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  @difficulties ~w(easy normal hard)

  attr :id, :string, required: true
  attr :status, :string, default: "ready"
  attr :selected_game, :map, required: true
  attr :difficulty, :string, default: "normal"
  attr :canvas_ready, :boolean, default: false
  attr :menu_open, :boolean, default: false, doc: "the menu held open over a running match"
  attr :result, Result, default: nil
  attr :record, :map, default: nil, doc: "the `Games.Results.card/1` of the match just written"
  attr :ranked?, :boolean, default: false, doc: "whether this player's matches are written down"
  attr :error_message, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :invite, doc: "the ready menu's other ways to play: a partner, a link"

  @spec retro_games_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def retro_games_panel(assigns) do
    assigns =
      assigns
      |> assign(:game, assigns.selected_game)
      |> assign(:difficulties, @difficulties)
      |> assign(:control_rows, control_rows(assigns.selected_game))
      |> assign(:pad, game_pad(assigns.selected_game))
      # A one-player game has no opponent: no difficulty, nobody to beat.
      |> assign(:alone, Catalog.solo_only?(assigns.selected_game.id))

    ~H"""
    <section id={@id} class={classes(["h-full min-h-0", @class])} {@rest}>
      <.game_stage
        id={"#{@id}-session"}
        data-testid={"retro-game-session-#{@game.id}"}
        menu_open={@status != "playing" or @menu_open}
        menu_lock={@status != "playing"}
        on_close={JS.push("retro_games_resume")}
        on_menu={@status == "playing" && JS.push("retro_games_menu")}
        pad={@pad}
        pad_idle={@status != "playing" or @menu_open}
        game_id={@game.id}
      >
        <%!-- The canvas stays through the result, the last picture of the
              match behind it; Again loads a fresh engine on it. --%>
        <div
          id={"#{@id}-session-canvas"}
          phx-hook="RetroGameCanvasHook"
          phx-update="ignore"
          data-game-id={@game.id}
          data-difficulty={@difficulty}
          tabindex="-1"
          class="relative h-full w-full"
          data-testid={"retro-game-canvas-#{@game.id}"}
        >
          <canvas width="640" height="480" class="block h-full w-full bg-black object-contain"></canvas>
          <div class="game-canvas__stub absolute inset-0 flex items-center justify-center bg-black text-xs font-bold text-white">
            {dgettext("games", "Loading game...")}
          </div>
        </div>

        <:menu>
          <.ready_menu
            :if={@status == "ready"}
            game={@game}
            alone={@alone}
            difficulty={@difficulty}
            difficulties={@difficulties}
            control_rows={@control_rows}
            canvas_ready={@canvas_ready}
            invite={@invite}
          />
          <.paused_menu :if={@status == "playing" and @menu_open} stage={"#{@id}-session"} />
          <.result_menu
            :if={@status == "finished"}
            game={@game}
            alone={@alone}
            result={@result}
            record={@record}
            ranked?={@ranked?}
          />
          <div
            :if={@status == "error"}
            class="grid justify-items-center gap-retro-8"
            data-testid="retro-game-error"
          >
            <Icons.icon_warning class="h-10 w-10" />
            <h4 class="arcade-title">{dgettext("games", "Could not start this game")}</h4>
            <p class="arcade-muted">{@error_message}</p>
            <.again_button />
          </div>
        </:menu>
      </.game_stage>
    </section>
    """
  end

  attr :game, :map, required: true
  attr :alone, :boolean, required: true
  attr :difficulty, :string, required: true
  attr :difficulties, :list, required: true
  attr :control_rows, :list, required: true
  attr :canvas_ready, :boolean, required: true
  attr :invite, :list, required: true

  # What to play and how, before the match: the game, what it plays to, its
  # keys, how hard the computer plays, and the ways to start.
  defp ready_menu(assigns) do
    ~H"""
    <header class="grid justify-items-center gap-retro-4" data-testid="retro-game-sidebar-header">
      <Icons.game_icon game_id={@game.id} class="h-12 w-12" />
      <h3 class="arcade-title">{@game.name}</h3>
      <p class="arcade-muted">{@game.tagline}</p>
    </header>

    <div class="flex flex-wrap justify-center gap-retro-6">
      <span class="arcade-badge" data-testid="retro-game-mode">
        {if @alone, do: dgettext("games", "Solo"), else: dgettext("games", "Solo AI")}
      </span>
      <span class="arcade-badge" data-testid="retro-game-goal">{goal_label(@game)}</span>
    </div>

    <%!-- The keys, for a keyboard; a touch screen plays with the pad. --%>
    <dl class="arcade-keys grid gap-retro-4 text-left" data-testid="retro-game-controls-panel">
      <div
        :for={row <- @control_rows}
        class="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-retro-8"
      >
        <dt class="arcade-muted">{row.label}</dt>
        <dd class="flex flex-wrap justify-end gap-retro-4">
          <kbd :for={key <- row.keys} class="arcade-key">{key}</kbd>
        </dd>
      </div>
    </dl>

    <div
      :if={not @alone}
      class="grid grid-cols-3 gap-retro-4"
      role="group"
      aria-label={dgettext("games", "Difficulty")}
      data-testid="retro-game-difficulty-panel"
    >
      <%!-- A choice of three, lit while chosen: a toggle, not a command. --%>
      <button
        :for={difficulty <- @difficulties}
        type="button"
        class="arcade-toggle"
        aria-pressed={to_string(@difficulty == difficulty)}
        phx-click="retro_games_set_difficulty"
        phx-value-difficulty={difficulty}
        data-testid={"retro-game-difficulty-#{difficulty}"}
      >
        {difficulty_label(difficulty)}
      </button>
    </div>

    <.button
      :if={@canvas_ready}
      variant="arcade"
      size="lg"
      class="w-full"
      phx-click="retro_games_start_ai"
      data-testid="retro-game-start-ai"
    >
      <:icon><.arcade_icon name={:play} /></:icon>
      {if @alone, do: dpgettext("games", "game", "Play"), else: dgettext("games", "Play vs AI")}
    </.button>
    <.button
      :if={not @canvas_ready}
      variant="arcade"
      size="lg"
      class="w-full"
      disabled
      data-testid="retro-game-start-disabled"
    >
      <:icon><.arcade_icon name={:play} /></:icon>
      {dgettext("games", "Loading")}
    </.button>

    <div :if={@invite != []} class="flex flex-wrap justify-center gap-retro-6">
      {render_slot(@invite)}
    </div>
    """
  end

  attr :stage, :string, required: true

  # The match, held: go on, end it as it stands, or take the whole screen.
  defp paused_menu(assigns) do
    ~H"""
    <h3 class="arcade-title" data-testid="retro-game-paused">{dgettext("games", "Paused")}</h3>
    <.button
      variant="arcade"
      size="lg"
      class="w-full"
      phx-click="retro_games_resume"
      data-testid="retro-game-resume"
    >
      <:icon><.arcade_icon name={:play} /></:icon>
      {dgettext("games", "Continue")}
    </.button>
    <div class="grid grid-cols-2 gap-retro-6">
      <.button
        variant="arcade-secondary"
        class="arcade-button--danger"
        phx-click="retro_games_end"
        data-testid="retro-game-end-match"
      >
        <:icon><.arcade_icon name={:stop} /></:icon>
        {dgettext("games", "End")}
      </.button>
      <.stage_fullscreen_button stage={@stage} />
    </div>
    <p class="arcade-muted">{dgettext("games", "Press Esc to go back to the game.")}</p>
    """
  end

  attr :game, :map, required: true
  attr :alone, :boolean, required: true
  attr :result, Result, default: nil
  attr :record, :map, default: nil
  attr :ranked?, :boolean, required: true

  defp result_menu(assigns) do
    ~H"""
    <div class="grid justify-items-center gap-retro-6" data-testid="retro-game-result">
      <Icons.game_icon game_id={@game.id} class="h-12 w-12" />
      <h4 class="arcade-title">{dgettext("games", "Match Finished")}</h4>
      <p :if={@alone} class="arcade-badge">
        {dgettext("games", "%{points} points", points: (@result && @result.p1_score) || 0)}
      </p>
      <p :if={not @alone} class="arcade-badge">
        {dgettext("games", "You %{you} x %{ai} AI",
          you: (@result && @result.p1_score) || 0,
          ai: (@result && @result.p2_score) || 0
        )}
      </p>
      <p :if={not @alone and verdict_label(@result)} data-testid="retro-game-verdict">
        {verdict_label(@result)}
      </p>
      <p
        :if={@result && @result.ended_early?}
        class="arcade-muted"
        data-testid="retro-game-ended-early"
      >
        {dgettext("games", "Ended early")}
      </p>
      <p
        :if={@record && @record.personal_best}
        class="arcade-badge"
        data-testid="retro-game-personal-best"
      >
        {dgettext("games", "Personal best")}
      </p>
      <%!-- Where the match went, or why it went nowhere: a signed-in
            player's result is in the game's channel and ranking, and a
            guest is told what would have put it there. --%>
      <p :if={@record} data-testid="retro-game-recorded">
        {dgettext("games", "Saved to your record.")}
      </p>
      <p :if={not @ranked?} class="arcade-muted" data-testid="retro-game-unranked">
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
      <.again_button />
      <%!-- Everything else about the game — partners, the ranking — is
            at its home and in its channel. --%>
      <p class="flex flex-wrap justify-center gap-x-retro-8">
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
    </div>
    """
  end

  defp again_button(assigns) do
    ~H"""
    <.button
      variant="arcade"
      size="lg"
      class="w-full"
      phx-click="retro_games_play_again"
      data-testid="retro-game-play-again"
    >
      <:icon><.arcade_icon name={:again} /></:icon>
      {dgettext("games", "Again")}
    </.button>
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

  def goal_label(%{id: id}) when id in ~w(hex_solitaire hex_solitaire_draw3 hex_freecell),
    do: dgettext("games", "Four piles, ace to king")

  def goal_label(%{id: id}) when id in ~w(hex_spider hex_spider_2suits hex_spider_4suits),
    do: dgettext("games", "Eight suits, king to ace")

  def goal_label(%{id: id}) when id in ~w(hex_mines hex_mines_intermediate hex_mines_expert),
    do: dgettext("games", "Clear every square without a mine")

  def goal_label(%{id: id}) when id in ~w(hex_sudoku hex_sudoku_medium hex_sudoku_hard),
    do: dgettext("games", "Every row, column and box holds 1 to 9")

  def goal_label(%{id: "hex_blocks"}), do: dgettext("games", "Clear rows as the pieces speed up")
  def goal_label(%{id: "hex_blocks_sprint"}), do: dgettext("games", "40 rows, as fast as you can")

  # The games played by touch on the canvas itself: no pad under them.
  @touch_game_ids ~w(hex_solitaire hex_solitaire_draw3 hex_freecell hex_spider hex_spider_2suits
                     hex_spider_4suits hex_mines hex_mines_intermediate hex_mines_expert hex_sudoku
                     hex_sudoku_medium hex_sudoku_hard)

  @arrows [{"↑", "up"}, {"↓", "down"}, {"←", "left"}, {"→", "right"}]

  @doc """
  The on-screen pad of `game`, read off its keys (`control_rows/1`): the
  arrows it uses on the cross, and a button for each row with a key that is
  not an arrow (nor W, A, S or D, the arrows' twins), named by the row and
  pressing that key as `KeyboardEvent.key` has it (" ", "Shift", "x"). Nil
  for a game played by touch on its own canvas.
  """
  @spec game_pad(%{required(:id) => String.t(), optional(atom()) => term()}) ::
          %{dirs: [String.t()], actions: [%{key: String.t(), label: String.t()}]} | nil
  def game_pad(%{id: id}) when id in @touch_game_ids, do: nil

  def game_pad(game) do
    rows = control_rows(game)
    keys = Enum.flat_map(rows, & &1.keys)

    actions =
      rows
      |> Enum.flat_map(fn row ->
        case Enum.find_value(row.keys, &action_key/1) do
          nil -> []
          key -> [%{key: key, label: row.label}]
        end
      end)
      |> Enum.uniq_by(& &1.key)

    %{dirs: for({arrow, dir} <- @arrows, arrow in keys, do: dir), actions: actions}
  end

  defp action_key("Space"), do: " "
  defp action_key("Shift"), do: "Shift"
  defp action_key(<<c>>) when c in ?A..?Z and c not in ~c"WASD", do: String.downcase(<<c>>)
  defp action_key(_key), do: nil

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
  def control_rows(%{id: id}) when id in ~w(hex_mines hex_mines_intermediate hex_mines_expert) do
    [
      %{
        label: dgettext("games", "Open a square"),
        keys: [dgettext("games", "Click"), dgettext("games", "Tap")]
      },
      %{
        label: dgettext("games", "Plant or lift a flag"),
        keys: [dgettext("games", "Right click"), dgettext("games", "Long press")]
      },
      %{
        label: dgettext("games", "Open around a flagged number"),
        keys: [dgettext("games", "Tap the number")]
      },
      %{
        label: dgettext("games", "Flag with a tap, on a phone"),
        keys: [dgettext("games", "Tap the switch")]
      }
    ]
  end

  # A tap on the grid and the keypad, or the keyboard: digits, arrows and three letters.
  def control_rows(%{id: id}) when id in ~w(hex_sudoku hex_sudoku_medium hex_sudoku_hard) do
    [
      %{
        label: dgettext("games", "Choose a square"),
        keys: [dgettext("games", "Tap"), "←", "↑", "→", "↓"]
      },
      %{label: dgettext("games", "Put a digit"), keys: ["1–9"]},
      %{label: dgettext("games", "Notes on or off"), keys: ["N"]},
      %{label: dgettext("games", "Erase a square"), keys: ["Delete", "Backspace"]},
      %{label: dgettext("games", "Hint (adds a minute)"), keys: ["H"]},
      %{label: dgettext("games", "Undo"), keys: ["Z"]}
    ]
  end

  # The keyboard on a desktop; on a phone, the buttons under the well.
  def control_rows(%{id: id}) when id in ~w(hex_blocks hex_blocks_sprint) do
    [
      %{label: dgettext("games", "Move"), keys: ["←", "→"]},
      %{label: dgettext("games", "Turn"), keys: ["↑", "X"]},
      %{label: dgettext("games", "Turn the other way"), keys: ["Z"]},
      %{label: dgettext("games", "Fall faster"), keys: ["↓"]},
      %{label: dgettext("games", "Drop to the bottom"), keys: ["Space"]},
      %{label: dgettext("games", "Keep a piece for later"), keys: ["C", "Shift"]}
    ]
  end

  def control_rows(%{id: id}) when id in ~w(hex_spider hex_spider_2suits hex_spider_4suits) do
    [
      %{label: dgettext("games", "Move a card to its place"), keys: [dgettext("games", "Tap")]},
      %{label: dgettext("games", "Move cards between piles"), keys: [dgettext("games", "Drag")]},
      %{label: dgettext("games", "Deal a row"), keys: [dgettext("games", "Tap the deck")]}
    ]
  end

  def control_rows(%{id: "hex_freecell"}) do
    [
      %{label: dgettext("games", "Move a card to its place"), keys: [dgettext("games", "Tap")]},
      %{label: dgettext("games", "Move cards between piles"), keys: [dgettext("games", "Drag")]}
    ]
  end

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
      # Two keys, two moves: each its own row, so the pad has a button for each.
      %{label: dgettext("games", "Fire"), keys: ["Space"]},
      %{label: dgettext("games", "Drop a mine"), keys: ["Shift", "Q"]}
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

  # A match ended early names nobody, whoever led: it says only that it ended early.
  defp verdict_label(%Result{ended_early?: true}), do: nil
  defp verdict_label(%Result{outcome: :p1}), do: dgettext("games", "You won")
  defp verdict_label(%Result{outcome: :p2}), do: dgettext("games", "AI won")
  defp verdict_label(%Result{outcome: :draw}), do: dgettext("games", "Draw")
  defp verdict_label(%Result{outcome: :coop_win}), do: dgettext("games", "Board cleared")
  defp verdict_label(%Result{outcome: :coop_loss}), do: dgettext("games", "Out of lives")
  defp verdict_label(_unknown), do: dgettext("games", "No winner reported")
end
