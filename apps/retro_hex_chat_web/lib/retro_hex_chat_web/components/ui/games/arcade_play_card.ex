defmodule RetroHexChatWeb.Components.UI.ArcadePlayCard do
  @moduledoc """
  Somebody started an arcade game: drawn under the line that said so, in the
  game's channel and in `#arcade`.

  The line above it is plain text in the server's language, for search and the
  public archive; this card is the same news in the reader's language, with the
  two ways onward a reader wants: play it too, or go where it is talked about.
  There is no score and no time — an arcade game never reports back.

  Play opens the in-app Arcade on the game's sheet, as the Games menu would;
  whoever has no identified nickname is asked to sign in first and comes back
  to the same game.

  ## Usage

      <.arcade_play_card card={%{play_id: 9, game_id: "doom_shareware", nickname: "ana", place: :feed, …}} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard
  import RetroHexChatWeb.Components.UI.Landing.GameCommunity, only: [around_name: 1, name_mark: 0]
  import RetroHexChatWeb.Components.UI.NickFlag

  alias RetroHexChat.Arcade
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  attr :card, :map,
    default: nil,
    doc: "a card from `Arcade.play_cards_for_messages/1`, or nil for a plain line"

  attr :class, :any, default: nil

  @spec arcade_play_card(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_play_card(assigns) do
    ~H"""
    <.chat_card
      :if={@card}
      layout={:row}
      class={@class}
      data-testid={"arcade-play-card-#{@card.play_id}"}
    >
      <:icon><Icons.game_icon game_id={@card.game_id} class="h-8 w-8" /></:icon>
      <:title>
        <.link
          patch={Paths.game_page_path(@card.game_id)}
          class="underline"
          data-testid="arcade-play-home"
        >
          {game_title(@card.game_id)}
        </.link>
      </:title>

      <:badge :if={engine = engine_name(@card.game_id)}>
        <.chat_card_badge tone={:muted}>
          {dgettext("games", "%{engine} Engine", engine: engine)}
        </.chat_card_badge>
      </:badge>

      <span class="block" data-testid="arcade-play-who">
        <.around_name text={dgettext("games", "%{nickname} started the game", nickname: name_mark())}>
          <.nick_flag locale={Map.get(@card, :locale)} class="mr-1" />
          <strong>
            {@card.nickname}
          </strong>
        </.around_name>
      </span>

      <:actions>
        <button
          type="button"
          class="underline"
          phx-click="open_arcade"
          phx-value-game-id={@card.game_id}
          data-testid="arcade-play-play"
        >
          {dpgettext("games", "game", "Play")}
        </button>
        <%!-- Under the line in the game's own channel this would be a way
              into the room the reader is already in. --%>
        <button
          :if={@card.place != :channel}
          type="button"
          class="underline"
          phx-click="conversations_join_popular"
          phx-value-channel={Arcade.channel_name(@card.game_id)}
          data-testid="arcade-play-channel"
        >
          {Arcade.channel_name(@card.game_id)}
        </button>
      </:actions>
    </.chat_card>
    """
  end

  defp engine_name(game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} -> Arcade.engine_name(game.engine)
      {:error, :not_found} -> nil
    end
  end

  @doc "An arcade game's full name: `DOOM: Knee-Deep in the Dead`."
  @spec game_title(String.t()) :: String.t()
  def game_title(game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} -> game.name
      {:error, :not_found} -> game_id
    end
  end
end
