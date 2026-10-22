defmodule RetroHexChatWeb.Components.UI.GameResultCard do
  @moduledoc """
  A finished Retro Games match, drawn under the line that announced it — in
  the game's channel and in the two players' conversation alike.

  The line above it is plain text in the server's language, for search and the
  public archive; this card is the same match in the reader's language, with
  the two ways onward a reader wants: play it yourself, or go where it is
  talked about.

  The words come from `game_result_text/1` and its siblings, which the game's
  public page uses too, so a match reads the same on a card and in a ranking.

  ## Usage

      <.game_result_card card={%{result_id: 9, game_id: "hex_pong", place: :private, …}} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard
  import RetroHexChatWeb.Components.UI.NickFlag

  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  attr :card, :map,
    default: nil,
    doc: "a card from `Games.Results.cards_for_messages/2`, or nil for a plain line"

  attr :class, :any, default: nil

  @spec game_result_card(map()) :: Phoenix.LiveView.Rendered.t()
  def game_result_card(assigns) do
    ~H"""
    <.chat_card
      :if={@card}
      layout={:row}
      class={@class}
      data-testid={"game-result-card-#{@card.result_id}"}
      data-outcome={@card.outcome}
    >
      <:icon><Icons.game_icon game_id={@card.game_id} class="h-8 w-8" /></:icon>
      <%!-- The game's name leads to its home — its ranking among the rest —
            opened over the chat. --%>
      <:title>
        <.link
          patch={Paths.game_page_path(@card.game_id)}
          class="underline"
          data-testid="game-result-home"
        >
          {Catalog.game_name(@card.game_id)}
        </.link>
      </:title>
      <:badge :if={@card.personal_best}>
        <.chat_card_badge tone={:live}>{dgettext("games", "Personal best")}</.chat_card_badge>
      </:badge>
      <:badge :if={not @card.ranked}>
        <.chat_card_badge tone={:muted}>{dgettext("games", "Ended early")}</.chat_card_badge>
      </:badge>

      <span class="block font-bold" data-testid="game-result-score">
        <.score_with_flags card={@card} />
      </span>
      <span class="block text-muted-foreground">
        {verdict(@card)}
        <span :if={duration = ChatHelpers.format_duration(div(@card.duration_ms, 1000))}>
          · {duration}
        </span>
      </span>

      <:actions>
        <.surface_link
          href={Paths.play_path(@card.game_id)}
          label={Catalog.game_name(@card.game_id)}
          data-testid="game-result-play"
        >
          {dpgettext("games", "game", "Play")}
        </.surface_link>
        <%!-- Under the line in the game's own channel this would be a way
              into the room the reader is already in. --%>
        <button
          :if={Map.get(@card, :place) != :channel}
          type="button"
          class="underline"
          phx-click="conversations_join_popular"
          phx-value-channel={Catalog.channel_name(@card.game_id)}
          data-testid="game-result-channel"
        >
          {Catalog.channel_name(@card.game_id)}
        </button>
      </:actions>
    </.chat_card>
    """
  end

  @doc "Both sides and both scores, host first: `ana 11 × 7 beto`."
  @spec score_line(map()) :: String.t()
  def score_line(card) do
    dgettext("games", "%{p1} %{p1_score} × %{p2_score} %{p2}",
      p1: card.p1_nickname,
      p2: opponent(card),
      p1_score: card.p1_score,
      p2_score: card.p2_score
    )
  end

  attr :card, :map, required: true
  attr :locales, :map, default: nil, doc: "nickname => locale; nil reads the card's own"

  @doc """
  `score_line/1` with each player's language flag right before their name.

  The flags go in after translation, at the places the translation put the
  names, so a language that orders the line differently still gets each flag
  beside the right person. The text is exactly `score_line/1`'s.
  """
  @spec score_with_flags(map()) :: Phoenix.LiveView.Rendered.t()
  def score_with_flags(assigns) do
    assigns = assign(assigns, :parts, score_parts(assigns.card, assigns.locales))

    ~H"""
    <.score_part :for={part <- @parts} part={part} />
    """
  end

  defp score_part(%{part: {:text, text}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H"{@text}"
  end

  defp score_part(%{part: {:player, nick, locale}} = assigns) do
    assigns = assign(assigns, nick: nick, locale: locale)
    ~H|<.nick_flag locale={@locale} class="mr-1" />{@nick}|
  end

  # Private-use marks stand in for the names while the line is translated;
  # nothing a translator writes or a nickname holds contains them.
  @p1_mark "\u{E000}1\u{E000}"
  @p2_mark "\u{E000}2\u{E000}"

  defp score_parts(card, locales) do
    line =
      dgettext("games", "%{p1} %{p1_score} × %{p2_score} %{p2}",
        p1: @p1_mark,
        p2: @p2_mark,
        p1_score: card.p1_score,
        p2_score: card.p2_score
      )

    ~r/(\x{E000}[12]\x{E000})/u
    |> Regex.split(line, include_captures: true, trim: true)
    |> Enum.map(fn
      @p1_mark -> {:player, card.p1_nickname, player_locale(card, :p1, locales)}
      @p2_mark -> {:player, opponent(card), player_locale(card, :p2, locales)}
      text -> {:text, text}
    end)
  end

  # The computer has no language; a person's comes from the page's lookup, or
  # from the card when the card carries it.
  defp player_locale(%{p2_nickname: nil}, :p2, _locales), do: nil

  defp player_locale(card, side, locales) when is_map(locales),
    do: Map.get(locales, Map.get(card, nickname_key(side)))

  defp player_locale(card, :p1, _locales), do: Map.get(card, :p1_locale)
  defp player_locale(card, :p2, _locales), do: Map.get(card, :p2_locale)

  defp nickname_key(:p1), do: :p1_nickname
  defp nickname_key(:p2), do: :p2_nickname

  @doc "Who the first player played: a person, or the computer at a difficulty."
  @spec opponent(map()) :: String.t()
  def opponent(%{p2_nickname: nickname}) when is_binary(nickname), do: nickname
  def opponent(%{difficulty: "easy"}), do: dgettext("games", "Computer (easy)")
  def opponent(%{difficulty: "hard"}), do: dgettext("games", "Computer (hard)")
  def opponent(_card), do: dgettext("games", "Computer")

  @doc "How the match ended, in a few words."
  @spec verdict(map()) :: String.t()
  def verdict(%{ranked: false}), do: dgettext("games", "Somebody left before the end")

  def verdict(%{outcome: :p1} = card),
    do: dgettext("games", "Winner: %{name}", name: card.p1_nickname)

  def verdict(%{outcome: :p2} = card),
    do: dgettext("games", "Winner: %{name}", name: opponent(card))

  def verdict(%{outcome: :draw}), do: dgettext("games", "Draw")
  def verdict(%{outcome: :coop_win}), do: dgettext("games", "Cleared together")
  def verdict(%{outcome: :coop_loss}), do: dgettext("games", "Out of lives")
  def verdict(_no_verdict), do: dgettext("games", "Match over")
end
