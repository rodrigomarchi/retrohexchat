defmodule RetroHexChatWeb.Components.UI.GameChannelBar do
  @moduledoc """
  The strip under a game channel's topic: the game the room is about — its
  name leads to the game's home, with every way to play it and who is
  winning — and the two things somebody reading it can do about that game
  right here — play it now, or offer a seat to the room — and, when one is
  being played in the open, the match to watch.

  An arcade game's channel (`#doom-shareware`) gets the same strip with one
  action: Play opens the in-app Arcade on the game. Nobody plays an arcade game
  with anybody, so there is no seat to offer and no match to watch.

  Drawn only in a game's own channel; any other channel gets nothing. A visitor sees the same strip as a member, and pressing anything on
  it is what asks them to sign in — the room shows what is on offer before it
  asks for an account.

  ## Usage

      <.game_channel_bar channel="#hex-pong" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard, only: [surface_link: 1]
  import RetroHexChatWeb.Components.UI.LiveMatch

  alias RetroHexChat.Arcade
  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  attr :channel, :string, default: nil

  attr :live_matches, :list,
    default: [],
    doc: "every match anybody may watch now; the strip shows its own game's first"

  attr :class, :any, default: nil

  @spec game_channel_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def game_channel_bar(assigns) do
    {kind, game_id} = game_of(assigns.channel)

    assigns =
      assigns
      |> assign(kind: kind, game_id: game_id)
      |> assign(:live, kind == :retro && live_match(assigns.live_matches, game_id))

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
      <%!-- The game's home is a page of this desktop: it opens over the chat,
            which stays where it is. --%>
      <.link
        patch={Paths.game_page_path(@game_id)}
        class="flex min-w-0 items-center gap-retro-4 underline"
        data-testid="game-channel-home"
      >
        <Icons.game_icon game_id={@game_id} class="h-4 w-4 shrink-0" />
        <span class="truncate font-bold">{game_title(@kind, @game_id)}</span>
      </.link>

      <%!-- The arcade opens in this desktop, on the game's sheet, as the
            Games menu would open it. --%>
      <button
        :if={@kind == :arcade}
        type="button"
        class="shrink-0 cursor-pointer whitespace-nowrap underline"
        phx-click="open_arcade"
        phx-value-game-id={@game_id}
        data-testid="game-channel-play"
      >
        {dpgettext("games", "game", "Play")}
      </button>

      <%!-- Two actions, read as one row of words: the strip is a line of the
            conversation's furniture, not a toolbar. --%>
      <.surface_link
        :if={@kind == :retro}
        href={Paths.play_path(@game_id)}
        label={Catalog.game_name(@game_id)}
        class="shrink-0"
        data-testid="game-channel-play"
      >
        {dpgettext("games", "game", "Play")}
      </.surface_link>

      <button
        :if={@kind == :retro}
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

  defp game_of(channel) when is_binary(channel) do
    case {Catalog.game_for_channel(channel), Arcade.game_for_channel(channel)} do
      {{:ok, game_id}, _arcade} -> {:retro, game_id}
      {:error, {:ok, game_id}} -> {:arcade, game_id}
      {:error, :error} -> {nil, nil}
    end
  end

  defp game_of(_no_channel), do: {nil, nil}

  defp game_title(:arcade, game_id), do: Arcade.game_name(game_id)
  defp game_title(:retro, game_id), do: Catalog.game_name(game_id)

  defp live_match(matches, game_id) do
    base_id = Catalog.base_id(game_id)
    Enum.find(matches, &(Catalog.base_id(&1.game_id) == base_id))
  end
end
