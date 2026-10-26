defmodule RetroHexChatWeb.Components.UI.Landing.GameCommunity do
  @moduledoc """
  The people around a Retro Game, on its home (`Landing.GameHome`): who is
  playing it now, who is winning, and what is said in its channel — one
  component per tab.

  It is the part of the page that changes every day, which is what makes the
  page worth coming back to — for a person and for a search engine — and all
  of it is in the first HTML the server sends.

  Their assigns come from the page: `channel`, `channel_path`, `ranking`
  (`:wins` or `:best`), `week` and `computer` (standings), `ratings` (Elo,
  shown for a versus game), `playing_now` (nicknames in a match right now),
  `live` (the matches among them anybody may watch), `challenge` and
  `challenge_leader` (the week's challenge), `recent` (match cards), `chatter`
  (archived lines) and `week_count` — and `nick_locales`, the language of
  every nickname among them (`nickname => locale`), looked up once by the page,
  for the flag drawn before each name.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.LiveMatch
  import RetroHexChatWeb.Components.UI.NickFlag

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Icons

  attr :live, :list, required: true
  attr :playing_now, :list, required: true
  attr :nick_locales, :map, default: %{}

  @doc "Who is playing the game now, and the matches among theirs anybody may watch."
  @spec live_now(map()) :: Phoenix.LiveView.Rendered.t()
  def live_now(assigns) do
    ~H"""
    <p :if={@playing_now == []} class="text-sm text-muted-foreground">
      {dgettext("landing", "Nobody yet.")}
    </p>
    <p :if={@playing_now != []} class="text-sm mb-3" data-testid="game-community-playing">
      <.around_name text={dgettext("landing", "Playing now: %{names}", names: name_mark())}>
        <.flagged_names names={@playing_now} locales={@nick_locales} />
      </.around_name>
    </p>

    <div :if={@live != []} data-testid="game-community-live">
      <h3 class="text-sm font-bold mb-1">{dgettext("landing", "Live now")}</h3>
      <ul class="text-sm space-y-1">
        <li :for={match <- @live}>
          <.live_match_link match={match} show_game={false} locales={@nick_locales} new_tab />
        </li>
      </ul>
    </div>
    """
  end

  @doc "Who is winning: the week's challenge, the week, the rating, the computer and the latest matches."
  @spec ranking(map()) :: Phoenix.LiveView.Rendered.t()
  def ranking(assigns) do
    ~H"""
    <div class="mb-3" data-testid="game-community-challenge">
      <h3 class="text-sm font-bold mb-1">
        {dgettext("landing", "Challenge of the week: %{game}",
          game: Catalog.game_name(@challenge.game_id)
        )}
      </h3>
      <p :if={@challenge_leader} class="text-sm">
        <.around_name text={dgettext("landing", "In the lead: %{nickname}", nickname: name_mark())}>
          <.nick_flag locale={Map.get(@nick_locales, @challenge_leader.nickname)} class="mr-1" />{@challenge_leader.nickname}
        </.around_name>
      </p>
    </div>

    <h3 :if={not @alone} class="text-sm font-bold mb-1">
      {dgettext("landing", "This week, between players")}
    </h3>
    <h3 :if={@alone} class="text-sm font-bold mb-1">{dgettext("landing", "This week")}</h3>
    <.standings
      standings={@week}
      ranking={@ranking}
      locales={@nick_locales}
      testid="game-community-week"
    />

    <div :if={@alone}>
      <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "Best scores")}</h3>
      <.standings
        standings={@best}
        ranking={@ranking}
        locales={@nick_locales}
        testid="game-community-best"
      />
    </div>

    <div :if={@ranking == :wins}>
      <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "Rating")}</h3>
      <p :if={@ratings == []} class="text-sm text-muted-foreground">
        {dgettext("landing", "Nobody yet.")}
      </p>
      <ol :if={@ratings != []} class="text-sm list-decimal pl-5" data-testid="game-community-ratings">
        <li :for={row <- @ratings}>
          <.nick_flag locale={Map.get(@nick_locales, row.nickname)} />
          <strong>{row.nickname}</strong>
          <span class="text-muted-foreground">{row.rating}</span>
        </li>
      </ol>
    </div>

    <div :if={not @alone}>
      <h3 class="text-sm font-bold mb-1 mt-3">
        {dgettext("landing", "Against the computer on hard")}
      </h3>
      <.standings
        standings={@computer}
        ranking={@ranking}
        locales={@nick_locales}
        testid="game-community-computer"
      />
    </div>

    <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "Latest matches")}</h3>
    <p :if={@recent == []} class="text-sm text-muted-foreground">
      {dgettext("landing", "No matches yet. Play the first one.")}
    </p>
    <.match_list
      :if={@recent != []}
      cards={@recent}
      locales={@nick_locales}
      testid="game-community-recent"
    />
    """
  end

  attr :cards, :list, required: true, doc: "`Games.Results.card/1`s, newest first"
  attr :testid, :string, required: true
  attr :locales, :map, default: %{}, doc: "nickname => locale, for the players' flags"

  @doc """
  Matches as lines: the score, how it ended — a match somebody left says so —
  and when.
  """
  @spec match_list(map()) :: Phoenix.LiveView.Rendered.t()
  def match_list(assigns) do
    ~H"""
    <ul class="text-sm space-y-1" data-testid={@testid}>
      <li :for={card <- @cards}>
        <strong><GameResultCard.score_with_flags card={card} locales={@locales} /></strong>
        <span class="text-muted-foreground">
          · {GameResultCard.verdict(card)} · {TimeFormatter.format_relative(card.finished_at)}
        </span>
      </li>
    </ul>
    """
  end

  @doc """
  The game's channel: how busy it is, its last lines, and the way in. The
  same corner closes an arcade game's home, where a game played is a game
  somebody started.
  """
  @spec channel_corner(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_corner(assigns) do
    ~H"""
    <h2 id="game-community-heading" class="text-sm font-bold mb-1">{@channel}</h2>
    <p class="text-sm mb-3" data-testid="game-community-count">{week_count(@week_count)}</p>

    <div :if={@chatter != []} class="mb-3" data-testid="game-community-chatter">
      <h3 class="text-sm font-bold mb-1">{dgettext("landing", "In the channel")}</h3>
      <ul class="text-sm space-y-1">
        <li :for={line <- @chatter} class="break-words">
          <.nick_flag locale={Map.get(@nick_locales, line.author)} />
          <strong>{line.author}</strong>: {line.text}
        </li>
      </ul>
    </div>

    <.button patch={@channel_path} data-testid="game-community-channel">
      <:icon><Icons.icon_chat class="w-4 h-4" /></:icon>
      {dgettext("landing", "Open the channel")}
    </.button>
    """
  end

  attr :standings, :list, required: true

  attr :ranking, :atom,
    required: true,
    values: [:wins, :best, :plays],
    doc: "what each row is ranked by: wins, best score, or games started"

  attr :locales, :map, default: %{}
  attr :testid, :string, required: true

  @doc """
  A ranked list of nicknames, each with its flag and what it is ranked by —
  the board every game's home draws, a multiplayer game's or an arcade's.
  """
  @spec standings(map()) :: Phoenix.LiveView.Rendered.t()
  def standings(assigns) do
    ~H"""
    <p :if={@standings == []} class="text-sm text-muted-foreground">
      {dgettext("landing", "Nobody yet.")}
    </p>
    <ol :if={@standings != []} class="text-sm list-decimal pl-5" data-testid={@testid}>
      <li :for={row <- @standings}>
        <.nick_flag locale={Map.get(@locales, row.nickname)} />
        <strong>{row.nickname}</strong>
        <span class="text-muted-foreground">{standing_value(row, @ranking)}</span>
      </li>
    </ol>
    """
  end

  # A private-use mark stands in for the name while a sentence is translated,
  # so the flagged name goes where the translation put it.
  @name_mark "\u{E000}"

  @doc "What a sentence passed to `around_name/1` is translated with, where the name goes."
  @spec name_mark() :: String.t()
  def name_mark, do: @name_mark

  attr :text, :string, required: true, doc: "a translation with `name_mark/0` where the name goes"
  slot :inner_block, required: true

  @doc """
  A translated sentence with the name — its flag before it — drawn where the
  translation put `name_mark/0`, whatever the language's word order.
  """
  @spec around_name(map()) :: Phoenix.LiveView.Rendered.t()
  def around_name(assigns) do
    {before, rest} =
      case String.split(assigns.text, @name_mark, parts: 2) do
        [before, rest] -> {before, rest}
        [whole] -> {whole, ""}
      end

    assigns = assign(assigns, before: before, rest: rest)

    ~H"{@before}{render_slot(@inner_block)}{@rest}"
  end

  attr :names, :list, required: true
  attr :locales, :map, required: true

  # A list of nicknames, each with its flag before it, comma-separated.
  defp flagged_names(assigns) do
    assigns = assign(assigns, :last, length(assigns.names) - 1)

    ~H"""
    <span :for={{name, index} <- Enum.with_index(@names)} class="whitespace-nowrap">
      <.nick_flag locale={Map.get(@locales, name)} class="mr-1" />{name}{if index < @last, do: ","}
    </span>
    """
  end

  defp week_count(count),
    do:
      dngettext(
        "landing",
        "%{count} game played this week",
        "%{count} games played this week",
        count,
        count: count
      )

  defp standing_value(row, :wins),
    do: dngettext("landing", "%{count} win", "%{count} wins", row.wins, count: row.wins)

  defp standing_value(row, :best),
    do: dgettext("landing", "best score: %{score}", score: row.best)

  defp standing_value(row, :plays),
    do:
      dngettext("landing", "started %{count} time", "started %{count} times", row.plays,
        count: row.plays
      )
end
