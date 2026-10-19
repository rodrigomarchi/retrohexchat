defmodule RetroHexChatWeb.Components.UI.Landing.GameHome do
  @moduledoc """
  A Retro Game's home: the one window every way into the game leads to.

  Five tabs, each a question somebody arriving here asks — how do I play it,
  who is playing it now, who is winning, how am I doing, who talks about it —
  over a header that says which game this is. Every tab is in the first HTML
  the server sends, so a search engine reads all of it; the tabs only choose
  which one a person sees.

  The game itself never runs here. Each way to play opens the game, or its
  match room, in a tab of its own, and the desktop — the chat — stays where it
  is. Looking for a partner and inviting somebody are the channel's commands,
  `/lfg` and `/challenge`, run in the game's channel.

  Its assigns come from the page (`RetroHexChatWeb.Site.Pages.Game`): `game`,
  `visitor`, `ways` (one per mode: `id`, `name`, `tagline`, `play_path`,
  `link_path`), `how_to_play_path`, `sign_in_path`, `you` (the reader's
  `Games.Results.player_record/3`, nil without a registered nickname),
  `register_path`, and the community's own —
  see `RetroHexChatWeb.Components.UI.Landing.GameCommunity`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ChatCard, only: [surface_link: 1]
  import RetroHexChatWeb.Components.UI.Landing.GameCards, only: [game_screenshot: 1]
  import RetroHexChatWeb.Components.UI.Landing.GameCommunity
  import RetroHexChatWeb.Components.UI.Tabs

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Icons

  @doc "The home window's body."
  @spec game_home(map()) :: Phoenix.LiveView.Rendered.t()
  def game_home(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-8 mb-retro-8">
      <span class="shadow-retro-field shrink-0 p-retro-4">
        <Icons.game_icon game_id={@game.id} class="h-8 w-8" />
      </span>
      <div class="min-w-0">
        <h1 id="game-heading" class="text-lg font-bold text-text">{@game.name}</h1>
        <p class="text-sm">{@game.tagline}</p>
      </div>
    </div>

    <.tabs :let={builder} id={"game-home-#{@game.id}"} default="play" data-testid="game-home">
      <.tabs_list>
        <.tabs_trigger
          :for={{value, label, icon} <- tabs(@live, @channel)}
          builder={builder}
          value={value}
          data-testid={"game-home-tab-#{value}"}
        >
          <:icon>
            <Icons.icon_joystick :if={icon == :joystick} class="h-4 w-4" />
            <Icons.icon_watching :if={icon == :watching} class="h-4 w-4" />
            <Icons.icon_star :if={icon == :star} class="h-4 w-4" />
            <Icons.icon_status_user :if={icon == :user} class="h-4 w-4" />
            <Icons.icon_chat :if={icon == :chat} class="h-4 w-4" />
          </:icon>
          {label}
        </.tabs_trigger>
      </.tabs_list>

      <.tabs_content builder={builder} value="play" data-testid="game-home-play">
        <.play_tab {assigns} />
      </.tabs_content>
      <.tabs_content builder={builder} value="live" data-testid="game-home-live">
        <.live_now live={@live} playing_now={@playing_now} />
      </.tabs_content>
      <.tabs_content builder={builder} value="ranking" data-testid="game-home-ranking">
        <.ranking {assigns} />
      </.tabs_content>
      <.tabs_content builder={builder} value="you" data-testid="game-home-you">
        <.your_record {assigns} />
      </.tabs_content>
      <.tabs_content builder={builder} value="channel" data-testid="game-home-channel">
        <.channel_corner {assigns} />
      </.tabs_content>
    </.tabs>
    """
  end

  # How to play it, mode by mode. A member gets the two ways in that need
  # nobody else's consent — the computer, and a seat offered to the channel —
  # on every mode, and below them the two that name somebody: a nickname, or a
  # link to hand over. A visitor gets one way in per mode, which asks for an
  # account first and comes back to the game.
  defp play_tab(assigns) do
    ~H"""
    <div class="flex flex-col gap-retro-12 sm:flex-row">
      <div class="shadow-retro-field shrink-0 self-start sm:w-[240px]">
        <.game_screenshot game={@game} main />
      </div>

      <div class="min-w-0 flex-1">
        <ul class="flex flex-col gap-retro-8" data-testid="game-ways">
          <li
            :for={way <- @ways}
            class="flex flex-wrap items-center gap-x-retro-8 gap-y-retro-4"
            data-testid={"game-way-#{way.id}"}
          >
            <div class="min-w-0 flex-1 basis-[160px]">
              <strong class="block text-sm">{way.name}</strong>
              <span class="block text-xs text-muted-foreground">{way.tagline}</span>
            </div>

            <.button
              :if={@visitor}
              size="sm"
              patch={@sign_in_path}
              class="shrink-0"
              data-testid="game-play"
            >
              <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
              {dgettext("landing", "Play now — pick a nickname")}
            </.button>

            <.surface_link
              :if={not @visitor}
              as={:button}
              href={way.play_path}
              label={way.name}
              data-testid="game-play"
            >
              <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
              {dgettext("games", "Against the computer")}
            </.surface_link>

            <.button
              :if={not @visitor}
              type="button"
              size="sm"
              variant="outline"
              class="shrink-0"
              phx-click="game_home_lfg"
              phx-value-game={way.id}
              title={
                dgettext(
                  "games",
                  "Offer a seat to this channel: whoever presses Join first plays you"
                )
              }
              data-testid="game-lfg"
            >
              <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
              {dgettext("games", "Find a partner")}
            </.button>
          </li>
        </ul>

        <div :if={not @visitor} class="mt-retro-12" data-testid="game-invite">
          <h2 class="text-sm font-bold mb-retro-4">
            {dgettext("games", "Play with somebody you know")}
          </h2>
          <form
            phx-submit="game_home_challenge"
            class="flex flex-wrap items-center gap-retro-4"
            data-testid="game-challenge-form"
          >
            <select
              :if={length(@ways) > 1}
              name="game"
              class="shadow-retro-field bg-white px-retro-4 py-retro-2 text-sm"
              aria-label={dgettext("games", "Mode")}
            >
              <option :for={way <- @ways} value={way.id}>{way.name}</option>
            </select>
            <input :if={length(@ways) == 1} type="hidden" name="game" value={@game.id} />
            <input
              type="text"
              name="nickname"
              required
              maxlength="30"
              autocomplete="off"
              placeholder={dgettext("games", "Nickname")}
              aria-label={dgettext("games", "Nickname")}
              class="shadow-retro-field bg-white px-retro-4 py-retro-2 text-sm min-w-0 flex-1 basis-[120px]"
              data-testid="game-challenge-nickname"
            />
            <.button type="submit" size="sm" data-testid="game-challenge">
              <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
              {dgettext("games", "Invite")}
            </.button>
          </form>
          <p class="text-xs mt-retro-6">
            <.surface_link
              href={hd(@ways).link_path}
              label={@game.name}
              data-testid="game-match-link"
            >
              {dgettext("games", "Create a match link")}
            </.surface_link>
          </p>
        </div>

        <h2 class="text-sm font-bold mt-retro-12 mb-1">{dgettext("landing", "About")}</h2>
        <p class="text-sm mb-3">{@game.description}</p>

        <h2 class="text-sm font-bold mb-1">{dgettext("landing", "Controls")}</h2>
        <p class="text-sm mb-3" data-testid="game-controls">{@game.controls}</p>

        <.button variant="outline" size="sm" patch={@how_to_play_path} data-testid="game-how-to-play">
          <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
          {dgettext("landing", "How to play")}
        </.button>
      </div>
    </div>
    """
  end

  defp tabs(live, channel) do
    [
      {"play", dpgettext("games", "game", "Play"), :joystick},
      {"live", live_label(live), :watching},
      {"ranking", dgettext("games", "Ranking"), :star},
      {"you", dpgettext("games", "player", "You"), :user},
      {"channel", channel, :chat}
    ]
  end

  # The reader's own place in the game. Only a registered nickname is in the
  # ranking, so anybody else is told how to get there rather than shown zeros.
  defp your_record(%{you: nil} = assigns) do
    ~H"""
    <p class="text-sm mb-retro-8" data-testid="game-you-unranked">
      {dgettext("games", "Sign in with a registered nickname to enter the ranking.")}
    </p>
    <.button :if={@visitor} size="sm" patch={@sign_in_path} data-testid="game-you-sign-in">
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

  defp your_record(%{you: %{people: nil, computer: nil, recent: []}} = assigns) do
    ~H"""
    <p class="text-sm" data-testid="game-you-none">
      {dgettext("landing", "No matches yet. Play the first one.")}
    </p>
    """
  end

  defp your_record(assigns) do
    ~H"""
    <div :if={@you.rating} class="mb-retro-12" data-testid="game-you-rating">
      <h3 class="text-sm font-bold mb-1">{dgettext("landing", "Rating")}</h3>
      <p class="text-sm">
        <strong class="text-base">{@you.rating.rating}</strong>
        <span class="text-muted-foreground">
          · {dgettext("games", "Place %{rank} of %{players}",
            rank: @you.rating.rank,
            players: @you.rating.players
          )}
        </span>
      </p>
      <p class="text-sm text-muted-foreground">
        {dgettext("games", "Wins")} {@you.rating.wins} · {dgettext("games", "Losses")} {@you.rating.losses} · {dgettext(
          "games",
          "Draws"
        )} {@you.rating.draws}
      </p>
    </div>

    <table class="text-sm mb-retro-12" data-testid="game-you-totals">
      <thead>
        <tr>
          <th></th>
          <th class="px-retro-8 text-left">{dgettext("games", "Against people")}</th>
          <th class="px-retro-8 text-left">{dgettext("games", "Against the computer")}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <th class="pr-retro-8 text-left font-normal">{dgettext("games", "Matches")}</th>
          <td class="px-retro-8">{total(@you.people, :matches)}</td>
          <td class="px-retro-8">{total(@you.computer, :matches)}</td>
        </tr>
        <tr>
          <th class="pr-retro-8 text-left font-normal">{dgettext("games", "Wins")}</th>
          <td class="px-retro-8">{total(@you.people, :wins)}</td>
          <td class="px-retro-8">{total(@you.computer, :wins)}</td>
        </tr>
        <tr :if={@ranking == :best}>
          <th class="pr-retro-8 text-left font-normal">{dgettext("games", "Best score")}</th>
          <td class="px-retro-8">{total(@you.people, :best)}</td>
          <td class="px-retro-8">{total(@you.computer, :best)}</td>
        </tr>
      </tbody>
    </table>

    <h3 class="text-sm font-bold mb-1">{dgettext("games", "Your latest matches")}</h3>
    <ul class="text-sm space-y-1" data-testid="game-you-recent">
      <li :for={card <- @you.recent}>
        <strong>{GameResultCard.score_line(card)}</strong>
        <span class="text-muted-foreground">
          · {GameResultCard.verdict(card)} · {TimeFormatter.format_relative(card.finished_at)}
        </span>
      </li>
    </ul>
    """
  end

  defp total(nil, _key), do: "—"
  defp total(totals, key), do: Map.get(totals, key) || "—"

  defp live_label([]), do: dpgettext("games", "match", "Live")
  defp live_label(live), do: "#{dpgettext("games", "match", "Live")} (#{length(live)})"
end
