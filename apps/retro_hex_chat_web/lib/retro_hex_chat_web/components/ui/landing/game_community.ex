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
  (archived lines) and `week_count`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.LiveMatch

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Icons

  attr :live, :list, required: true
  attr :playing_now, :list, required: true

  @doc "Who is playing the game now, and the matches among theirs anybody may watch."
  @spec live_now(map()) :: Phoenix.LiveView.Rendered.t()
  def live_now(assigns) do
    ~H"""
    <p :if={@playing_now == []} class="text-sm text-muted-foreground">
      {dgettext("landing", "Nobody yet.")}
    </p>
    <p :if={@playing_now != []} class="text-sm mb-3" data-testid="game-community-playing">
      {dgettext("landing", "Playing now: %{names}", names: Enum.join(@playing_now, ", "))}
    </p>

    <div :if={@live != []} data-testid="game-community-live">
      <h3 class="text-sm font-bold mb-1">{dgettext("landing", "Live now")}</h3>
      <ul class="text-sm space-y-1">
        <li :for={match <- @live}>
          <.live_match_link match={match} show_game={false} new_tab />
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
          game: GameResultCard.game_title(@challenge.game_id)
        )}
      </h3>
      <p :if={@challenge_leader} class="text-sm">
        {dgettext("landing", "In the lead: %{nickname}", nickname: @challenge_leader.nickname)}
      </p>
    </div>

    <h3 class="text-sm font-bold mb-1">{dgettext("landing", "This week, between players")}</h3>
    <.standings standings={@week} ranking={@ranking} testid="game-community-week" />

    <div :if={@ranking == :wins}>
      <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "Rating")}</h3>
      <p :if={@ratings == []} class="text-sm text-muted-foreground">
        {dgettext("landing", "Nobody yet.")}
      </p>
      <ol :if={@ratings != []} class="text-sm list-decimal pl-5" data-testid="game-community-ratings">
        <li :for={row <- @ratings}>
          <strong>{row.nickname}</strong>
          <span class="text-muted-foreground">{row.rating}</span>
        </li>
      </ol>
    </div>

    <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "Against the computer on hard")}</h3>
    <.standings standings={@computer} ranking={@ranking} testid="game-community-computer" />

    <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "Latest matches")}</h3>
    <p :if={@recent == []} class="text-sm text-muted-foreground">
      {dgettext("landing", "No matches yet. Play the first one.")}
    </p>
    <ul :if={@recent != []} class="text-sm space-y-1" data-testid="game-community-recent">
      <li :for={card <- @recent}>
        <strong>{GameResultCard.score_line(card)}</strong>
        <span class="text-muted-foreground">
          · {GameResultCard.verdict(card)} · {TimeFormatter.format_relative(card.finished_at)}
        </span>
      </li>
    </ul>
    """
  end

  @doc "The game's channel: how busy it is, its last lines, and the way in."
  @spec channel_corner(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_corner(assigns) do
    ~H"""
    <h2 id="game-community-heading" class="text-sm font-bold mb-1">{@channel}</h2>
    <p class="text-sm mb-3" data-testid="game-community-count">
      {dngettext(
        "landing",
        "%{count} game played this week.",
        "%{count} games played this week.",
        @week_count,
        count: @week_count
      )}
    </p>

    <div :if={@chatter != []} class="mb-3" data-testid="game-community-chatter">
      <h3 class="text-sm font-bold mb-1">{dgettext("landing", "In the channel")}</h3>
      <ul class="text-sm space-y-1">
        <li :for={line <- @chatter} class="break-words">
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
  attr :ranking, :atom, required: true
  attr :testid, :string, required: true

  defp standings(assigns) do
    ~H"""
    <p :if={@standings == []} class="text-sm text-muted-foreground">
      {dgettext("landing", "Nobody yet.")}
    </p>
    <ol :if={@standings != []} class="text-sm list-decimal pl-5" data-testid={@testid}>
      <li :for={row <- @standings}>
        <strong>{row.nickname}</strong>
        <span class="text-muted-foreground">{standing_value(row, @ranking)}</span>
      </li>
    </ol>
    """
  end

  defp standing_value(row, :wins),
    do: dngettext("landing", "%{count} win", "%{count} wins", row.wins, count: row.wins)

  defp standing_value(row, :best),
    do: dgettext("landing", "best score: %{score}", score: row.best)
end
