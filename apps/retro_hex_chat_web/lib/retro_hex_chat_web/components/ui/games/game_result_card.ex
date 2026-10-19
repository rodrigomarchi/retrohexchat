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
      <:title>{game_title(@card.game_id)}</:title>
      <:badge :if={@card.personal_best}>
        <.chat_card_badge tone={:live}>{dgettext("games", "Personal best")}</.chat_card_badge>
      </:badge>
      <:badge :if={not @card.ranked}>
        <.chat_card_badge tone={:muted}>{dgettext("games", "Ended early")}</.chat_card_badge>
      </:badge>

      <span class="block font-bold" data-testid="game-result-score">
        {score_line(@card)}
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
          label={game_title(@card.game_id)}
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

  @doc "A game's or a mode's full name: `Hex Tennis: Quick Match`."
  @spec game_title(String.t()) :: String.t()
  def game_title(game_id) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> game.name
      {:error, :not_found} -> game_id
    end
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
