defmodule RetroHexChatWeb.Components.UI.LiveMatch do
  @moduledoc """
  A match being played now that anybody may watch, as one line that leads to
  it: who is playing, what, and how many are already watching.

  The one way a live match is drawn wherever it is offered — the watch page's
  "live now", a game channel's strip, the game's public page — so the four
  places say the same thing the same way. Its data is a
  `Games.Activity.live_match/0`.

  ## Usage

      <.live_match_link match={match} />
      <.live_match_link match={match} show_game={false} new_tab />

  `new_tab` where the line sits in a conversation: the match opens beside it
  instead of taking its place.

  Each player's name carries the flag of their language. The languages come
  with the match — `:player_locales`, put on a whole list at once by
  `put_player_locales/1` — or, where the page already looked up every
  nickname it names, as `locales`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard, only: [surface_link: 1]
  import RetroHexChatWeb.Components.UI.NickFlag

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Icons

  attr :match, :map, required: true
  attr :show_game, :boolean, default: true, doc: "false where the game is already said"
  attr :new_tab, :boolean, default: false, doc: "opens the match in a tab of its own"

  attr :locales, :map,
    default: nil,
    doc: "players' locales by nickname, when not carried by the match as `:player_locales`"

  attr :class, :any, default: nil

  @spec live_match_link(map()) :: Phoenix.LiveView.Rendered.t()
  def live_match_link(%{new_tab: true} = assigns) do
    ~H"""
    <.surface_link
      href={Paths.watch_path(@match.token)}
      label={dgettext("games", "Watching a match")}
      class={classes(["inline-flex min-w-0 items-center gap-retro-4", @class])}
      data-testid="live-match-link"
      data-token={@match.token}
    >
      <.match_label match={@match} show_game={@show_game} locales={@locales} />
    </.surface_link>
    """
  end

  def live_match_link(assigns) do
    ~H"""
    <.link
      href={Paths.watch_path(@match.token)}
      class={classes(["inline-flex min-w-0 items-center gap-retro-4 underline", @class])}
      data-testid="live-match-link"
      data-token={@match.token}
    >
      <.match_label match={@match} show_game={@show_game} locales={@locales} />
    </.link>
    """
  end

  attr :match, :map, required: true
  attr :show_game, :boolean, required: true
  attr :locales, :map, default: nil

  defp match_label(assigns) do
    assigns =
      assign(assigns, :locales, assigns.locales || Map.get(assigns.match, :player_locales, %{}))

    ~H"""
    <Icons.icon_watching class="h-4 w-4 shrink-0" />
    <span class="shrink-0">{dpgettext("games", "match", "Watch")}</span>
    <span :if={@show_game} class="shrink-0 font-bold">
      {GameResultCard.game_title(@match.game_id)}
    </span>
    <span class="truncate"><.match_players players={@match.players} locales={@locales} /></span>
    <span :if={@match.watchers > 0} class="text-muted-foreground shrink-0">
      {watchers_label(@match.watchers)}
    </span>
    """
  end

  attr :players, :list, required: true, doc: "the nicknames, nil for a seat nobody holds"
  attr :locales, :map, default: %{}, doc: "their locales by nickname"

  @doc """
  The sides of a match, drawn: each nickname after the flag of its language,
  set apart as a score is — `players_line/1` with the flags.
  """
  @spec match_players(map()) :: Phoenix.LiveView.Rendered.t()
  def match_players(assigns) do
    players = Enum.reject(assigns.players, &is_nil/1)
    assigns = assign(assigns, players: players, last: length(players) - 1)

    ~H"""
    <span
      :for={{name, index} <- Enum.with_index(@players)}
      class="whitespace-nowrap"
      data-testid="match-player"
    >
      <.nick_flag locale={Map.get(@locales, name)} class="mr-1" />{name}{if index < @last, do: " × "}
    </span>
    """
  end

  @doc """
  Gives every match of `matches` the languages of its players, as
  `:player_locales` — one lookup for the whole list.
  """
  @spec put_player_locales([map()]) :: [map()]
  def put_player_locales(matches) do
    put_player_locales(matches, matches |> player_nicks() |> NickLocales.for_nicks())
  end

  @doc "Gives every match of `matches` its players' languages, taken from `locales`."
  @spec put_player_locales([map()], %{String.t() => String.t()}) :: [map()]
  def put_player_locales(matches, locales) do
    Enum.map(matches, &Map.put(&1, :player_locales, Map.take(locales, &1.players)))
  end

  @doc "Everybody playing in `matches`, once each."
  @spec player_nicks([map()]) :: [String.t()]
  def player_nicks(matches) do
    matches |> Enum.flat_map(& &1.players) |> Enum.reject(&is_nil/1) |> Enum.uniq()
  end

  @doc "The sides of a match, as one line: nicknames, set apart as a score is."
  @spec players_line([String.t() | nil]) :: String.t()
  def players_line(players), do: players |> Enum.reject(&is_nil/1) |> Enum.join(" × ")

  @doc "How many are watching, as a short phrase."
  @spec watchers_label(non_neg_integer()) :: String.t()
  def watchers_label(count),
    do: dngettext("games", "%{count} watching", "%{count} watching", count, count: count)
end
