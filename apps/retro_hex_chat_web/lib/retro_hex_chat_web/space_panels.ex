defmodule RetroHexChatWeb.SpacePanels do
  @moduledoc """
  The panels a Construct piece opens, ready for the canvas to show.

  The domain fills in what it reads from the conversation
  (`VirtualSpace.fill_construct_panel/3`); this adds what only the web layer
  knows: the address a picture is served from, the games an arcade cabinet
  lists (each with its cover and the page it opens on), and the character
  portrait of whoever posted the picture or pinned a line.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.LiveMatch
  alias RetroHexChatWeb.Components.UI.NickFlag
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.SpaceRef

  @panels ~w(sign board screen arcade)

  @doc """
  The panel `nickname` opened in the space `space_id`. A modal that is not a
  Construct panel (a gate's question) is returned as it came.
  """
  @spec fill(map(), String.t(), String.t() | nil) :: map()
  def fill(%{kind: kind} = modal, space_id, nickname) when kind in @panels do
    case conversation(space_id) do
      {:ok, conversation} ->
        modal
        |> VirtualSpace.fill_construct_panel(conversation, nickname)
        |> for_the_page()

      :error ->
        modal
    end
  end

  def fill(modal, _space_id, _nickname), do: modal

  defp for_the_page(%{kind: "screen", image: %{id: id} = image} = modal) do
    image = %{
      url: "/chat/attachments/#{id}/preview",
      name: image.filename,
      author: image.author,
      avatar: portrait(image.author),
      flag: NickFlag.payload(NickLocales.for_nick(image.author))
    }

    %{modal | image: image}
  end

  defp for_the_page(%{kind: "board", pins: [_ | _] = pins} = modal) do
    authors = Enum.map(pins, & &1.author)
    avatars = Avatars.for_nicks(authors)
    locales = NickLocales.for_nicks(authors)

    pins =
      Enum.map(pins, fn pin ->
        pin
        |> Map.put(:avatar, Map.get(avatars, pin.author))
        |> Map.put(:flag, NickFlag.payload(Map.get(locales, pin.author)))
      end)

    %{modal | pins: pins}
  end

  # A cabinet the Game Room came with plays one game: that game is up front —
  # who is at it, a way to play it and the way into its channel — with the
  # rest of the shelf under it. A cabinet somebody placed shelves them all.
  defp for_the_page(%{kind: "arcade"} = modal) do
    playing = Activity.now() |> Map.values() |> Enum.frequencies_by(&Catalog.base_id(&1.game_id))
    shelf = Enum.map(GameCatalog.list(), &shelved(&1, playing))
    {featured, others} = Enum.split_with(shelf, &(&1.id == Map.get(modal, :game_id)))

    modal
    |> Map.put(:games, if(featured == [], do: shelf, else: others))
    |> Map.put(:featured, featured |> List.first() |> featured())
  end

  defp for_the_page(modal), do: modal

  defp shelved(game, playing) do
    %{
      id: game.id,
      name: game.name,
      tagline: game.tagline,
      url: game_url(game),
      cover: game.screenshot && game.screenshot.path,
      activity: activity(Map.get(playing, game.id, 0))
    }
  end

  # The words are the server's, in the reader's language, like the rest of
  # what the panel says about a game.
  defp featured(nil), do: nil

  defp featured(game) do
    channel = Catalog.channel_name(game.id)

    # The cabinet's own game is played right here, and its home is a click away.
    Map.merge(game, %{
      url: Paths.play_path(game.id),
      home_url: Paths.game_page_path(game.id),
      home_label: dgettext("share", "Other ways to play"),
      channel: channel,
      channel_url: Paths.chat_path(channel),
      playing: playing_now(Activity.playing_in(game.id)),
      nobody: dgettext("games", "No one is playing this game now."),
      live: Enum.map(Activity.live_matches(game.id), &live_match/1),
      live_label: dgettext("games", "Live now"),
      play_label: dpgettext("games", "game", "Play"),
      others_label: dgettext("games", "Other games")
    })
  end

  # A match being played in the open, as the cabinet lists it: one line, and
  # the page it is watched at.
  defp live_match(match) do
    label =
      [
        LiveMatch.players_line(match.players),
        match.watchers > 0 && LiveMatch.watchers_label(match.watchers)
      ]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" · ")

    %{token: match.token, url: Paths.watch_path(match.token), label: label}
  end

  defp playing_now([]), do: nil

  defp playing_now(names),
    do: dgettext("games", "Playing now: %{names}", names: Enum.join(names, ", "))

  # A cabinet with somebody at it says so: the room is busier than it looks.
  defp activity(0), do: nil

  defp activity(count),
    do: dngettext("games", "%{count} playing now", "%{count} playing now", count, count: count)

  defp portrait(author) when is_binary(author), do: Map.get(Avatars.for_nicks([author]), author)
  defp portrait(_nobody), do: nil

  # The shelf opens a game in a new tab, and the Space stays where it is: an
  # arcade game itself, a Retro Game at its home — every way to play it.
  defp game_url(%{kind: :arcade, id: id}), do: Paths.arcade_path(id)
  defp game_url(%{kind: :multiplayer, id: id}), do: Paths.game_page_path(id)

  defp conversation(space_id) do
    case VirtualSpace.construct_parent(space_id) do
      {:ok, "dm:" <> _pair} ->
        with {:ok, participants} <- SpaceRef.participants(space_id),
             do: {:ok, {:direct_message, participants}}

      {:ok, channel_name} ->
        {:ok, {:channel, channel_name}}

      :error ->
        :error
    end
  end
end
