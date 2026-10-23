defmodule RetroHexChatWeb.Components.UI.Landing.ArcadeHome do
  @moduledoc """
  An arcade game's home: the one window its public page, its channel and the
  cards in `#arcade` lead to — the arcade's counterpart of `Landing.GameHome`.

  Five tabs, each a question somebody arriving here asks — how do I play it,
  who played it lately, who plays it most, how often have I, who talks about
  it. Every tab is in the first HTML the server sends, so a search engine
  reads all of it; the tabs only choose which one a person sees.

  An arcade game reports nothing back: it runs in a tab of its own, on another
  address. So the home counts what the app does know — somebody pressing Play
  — and never claims a score, a time played, or that anybody is playing now.

  Its assigns come from the page (`RetroHexChatWeb.Site.Pages.Game`): `game`,
  `visitor`, `play_path`, `how_to_play_path`, `register_path`, `identified`,
  `recent` (plays, newest first), `week` and `all_time` (who plays it most),
  `you` (the reader's `Arcade.player_plays/2`, nil without a proved
  nickname), `channel`, `channel_path`, `chatter`, `week_count`, and
  `nick_locales` for the flag before each name.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Landing.GameCards, only: [game_detail: 1]

  import RetroHexChatWeb.Components.UI.Landing.GameCommunity,
    only: [channel_corner: 1, standings: 1]

  import RetroHexChatWeb.Components.UI.NickFlag
  import RetroHexChatWeb.Components.UI.Tabs

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChatWeb.Icons

  @doc "The home window's body."
  @spec arcade_home(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_home(assigns) do
    ~H"""
    <.tabs :let={builder} id={"game-home-#{@game.id}"} default="play" data-testid="game-home">
      <%!-- Five tabs are wider than a phone: they wrap onto a second row,
            as a Win98 tab control does, rather than pushing the panel sideways. --%>
      <.tabs_list class="flex-wrap gap-y-retro-2">
        <.tabs_trigger
          :for={{value, label, icon} <- home_tabs(@channel)}
          builder={builder}
          value={value}
          data-testid={"game-home-tab-#{value}"}
        >
          <:icon>
            <Icons.icon_joystick :if={icon == :joystick} class="h-4 w-4" />
            <Icons.icon_clock :if={icon == :clock} class="h-4 w-4" />
            <Icons.icon_star :if={icon == :star} class="h-4 w-4" />
            <Icons.icon_status_user :if={icon == :user} class="h-4 w-4" />
            <Icons.icon_chat :if={icon == :chat} class="h-4 w-4" />
          </:icon>
          {label}
        </.tabs_trigger>
      </.tabs_list>

      <.tabs_content builder={builder} value="play" data-testid="game-home-play">
        <.game_detail {assigns} />
      </.tabs_content>
      <.tabs_content builder={builder} value="players" data-testid="game-home-players">
        <.recent_plays recent={@recent} nick_locales={@nick_locales} />
      </.tabs_content>
      <.tabs_content builder={builder} value="ranking" data-testid="game-home-ranking">
        <h3 class="text-sm font-bold mb-1">{dgettext("landing", "This week")}</h3>
        <.standings
          standings={@week}
          ranking={:plays}
          locales={@nick_locales}
          testid="arcade-home-week"
        />
        <h3 class="text-sm font-bold mb-1 mt-3">{dgettext("landing", "All time")}</h3>
        <.standings
          standings={@all_time}
          ranking={:plays}
          locales={@nick_locales}
          testid="arcade-home-all-time"
        />
      </.tabs_content>
      <.tabs_content builder={builder} value="you" data-testid="game-home-you">
        <.your_plays {assigns} />
      </.tabs_content>
      <.tabs_content builder={builder} value="channel" data-testid="game-home-channel">
        <.channel_corner {assigns} />
      </.tabs_content>
    </.tabs>
    """
  end

  defp home_tabs(channel) do
    [
      {"play", dpgettext("games", "game", "Play"), :joystick},
      {"players", dgettext("landing", "Who played"), :clock},
      {"ranking", dgettext("landing", "Top players"), :star},
      {"you", dpgettext("games", "player", "You"), :user},
      {"channel", channel, :chat}
    ]
  end

  attr :recent, :list, required: true
  attr :nick_locales, :map, required: true

  defp recent_plays(%{recent: []} = assigns) do
    ~H"""
    <p class="text-sm text-muted-foreground" data-testid="arcade-home-recent-none">
      {dgettext("landing", "Nobody yet.")}
    </p>
    """
  end

  defp recent_plays(assigns) do
    ~H"""
    <ul class="text-sm space-y-1" data-testid="arcade-home-recent">
      <li :for={play <- @recent}>
        <.nick_flag locale={Map.get(@nick_locales, play.nickname)} />
        <strong>{play.nickname}</strong>
        <span class="text-muted-foreground">· {TimeFormatter.format_relative(play.started_at)}</span>
      </li>
    </ul>
    """
  end

  # The reader's own plays. Only a nickname this session has proved has any,
  # so anybody else is told how to get one rather than shown zeros.
  defp your_plays(%{you: nil} = assigns) do
    ~H"""
    <p class="text-sm mb-retro-8" data-testid="game-you-unranked">
      {dgettext("games", "Only registered nicknames appear in the ranking.")}
    </p>
    <.button :if={@visitor} size="sm" patch={@play_path} data-testid="game-you-sign-in">
      <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
      {dgettext("landing", "Play now — pick a nickname")}
    </.button>
    <.link
      :if={not @visitor}
      patch={@register_path}
      class="text-sm underline"
      data-testid="game-you-register"
    >
      {dgettext("games", "How to register")}
    </.link>
    """
  end

  defp your_plays(%{you: %{plays: 0}} = assigns) do
    ~H"""
    <p class="text-sm" data-testid="game-you-none">
      {dgettext("landing", "You have not started this game yet.")}
    </p>
    """
  end

  defp your_plays(assigns) do
    ~H"""
    <p class="text-sm" data-testid="game-you-plays">
      {dngettext(
        "landing",
        "You have started this game %{count} time.",
        "You have started this game %{count} times.",
        @you.plays,
        count: @you.plays
      )}
    </p>
    <p class="text-sm text-muted-foreground">
      {dgettext("landing", "Most recent start: %{when}",
        when: TimeFormatter.format_relative(@you.last_at)
      )}
    </p>
    """
  end
end
