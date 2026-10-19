defmodule RetroHexChatWeb.Components.UI.GameChannelBar do
  @moduledoc """
  The strip under a game channel's topic: the game the room is about, and the
  three things somebody reading it can do about that game — play it now,
  offer a seat to the room, or look at who is winning — and, when one is being
  played in the open, the match to watch.

  Drawn only in a game's own channel (`#hex-pong`); any other channel gets
  nothing. A visitor sees the same strip as a member, and pressing anything on
  it is what asks them to sign in — the room shows what is on offer before it
  asks for an account.

  ## Usage

      <.game_channel_bar channel="#hex-pong" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard, only: [surface_link: 1]
  import RetroHexChatWeb.Components.UI.LiveMatch

  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages

  attr :channel, :string, default: nil

  attr :live_matches, :list,
    default: [],
    doc: "every match anybody may watch now; the strip shows its own game's first"

  attr :class, :any, default: nil

  @spec game_channel_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def game_channel_bar(assigns) do
    game_id = game_id(assigns.channel)

    assigns =
      assigns
      |> assign(:game_id, game_id)
      |> assign(:live, game_id && live_match(assigns.live_matches, game_id))

    ~H"""
    <div
      :if={@game_id}
      class={
        classes([
          "flex flex-wrap items-center gap-x-retro-8 gap-y-retro-2 px-retro-4 py-retro-2 text-xs",
          @class
        ])
      }
      data-testid="game-channel-bar"
      data-game-id={@game_id}
    >
      <span class="flex min-w-0 items-center gap-retro-4">
        <Icons.game_icon game_id={@game_id} class="h-4 w-4 shrink-0" />
        <span class="truncate font-bold">{GameResultCard.game_title(@game_id)}</span>
      </span>

      <%!-- Three actions, read as one row of words: the strip is a line of the
            conversation's furniture, not a toolbar. --%>
      <.surface_link
        href={Paths.play_path(@game_id)}
        label={GameResultCard.game_title(@game_id)}
        class="shrink-0"
        data-testid="game-channel-play"
      >
        {dpgettext("games", "game", "Play")}
      </.surface_link>

      <button
        type="button"
        class="shrink-0 cursor-pointer whitespace-nowrap underline"
        title={
          dgettext("games", "Offer a seat to this channel: whoever presses Join first plays you")
        }
        phx-click="game_lfg"
        data-testid="game-channel-lfg"
      >
        {dgettext("games", "Find a partner")}
      </button>

      <.link
        href={PublicPages.localized_path("/games/" <> Catalog.slug(@game_id))}
        target="_blank"
        rel="noopener"
        class="shrink-0 whitespace-nowrap underline"
        data-testid="game-channel-ranking"
      >
        {dgettext("games", "Ranking")}
      </.link>

      <%!-- The strip is redrawn when somebody starts or stops playing, not
            when somebody starts watching, so it names no count it would
            leave stale. --%>
      <.live_match_link
        :if={@live}
        match={%{@live | watchers: 0}}
        show_game={false}
        new_tab
        class="ml-auto"
      />
    </div>
    """
  end

  defp game_id(channel) when is_binary(channel) do
    case Catalog.game_for_channel(channel) do
      {:ok, game_id} -> game_id
      :error -> nil
    end
  end

  defp game_id(_no_channel), do: nil

  defp live_match(matches, game_id) do
    base_id = Catalog.base_id(game_id)
    Enum.find(matches, &(Catalog.base_id(&1.game_id) == base_id))
  end
end
