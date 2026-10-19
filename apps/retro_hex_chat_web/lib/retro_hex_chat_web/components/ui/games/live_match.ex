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
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard, only: [surface_link: 1]

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Icons

  attr :match, :map, required: true
  attr :show_game, :boolean, default: true, doc: "false where the game is already said"
  attr :new_tab, :boolean, default: false, doc: "opens the match in a tab of its own"
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
      <.match_label match={@match} show_game={@show_game} />
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
      <.match_label match={@match} show_game={@show_game} />
    </.link>
    """
  end

  attr :match, :map, required: true
  attr :show_game, :boolean, required: true

  defp match_label(assigns) do
    ~H"""
    <Icons.icon_watching class="h-4 w-4 shrink-0" />
    <span class="shrink-0">{dpgettext("games", "match", "Watch")}</span>
    <span :if={@show_game} class="shrink-0 font-bold">
      {GameResultCard.game_title(@match.game_id)}
    </span>
    <span class="truncate">{players_line(@match.players)}</span>
    <span :if={@match.watchers > 0} class="text-muted-foreground shrink-0">
      {watchers_label(@match.watchers)}
    </span>
    """
  end

  @doc "The sides of a match, as one line: nicknames, set apart as a score is."
  @spec players_line([String.t() | nil]) :: String.t()
  def players_line(players), do: players |> Enum.reject(&is_nil/1) |> Enum.join(" × ")

  @doc "How many are watching, as a short phrase."
  @spec watchers_label(non_neg_integer()) :: String.t()
  def watchers_label(count),
    do: dngettext("games", "%{count} watching", "%{count} watching", count, count: count)
end
