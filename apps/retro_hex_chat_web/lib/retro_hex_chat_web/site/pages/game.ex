defmodule RetroHexChatWeb.Site.Pages.Game do
  @moduledoc """
  One game's public page: what it is, what it looks like, and the way in.

  This is the page a search for "play DOOM in the browser" should land on, so
  it says that in its title and shows the game itself. An arcade game's page
  is its home in the desktop (`Landing.ArcadeHome`): its sheet (`GameSheet`) —
  what it is, its keys, its tips — the same one the in-app Arcade opens on
  once the reader has a nickname, and beside it who started it lately, who
  plays it most and what its channel says.

  A Retro Game's page is its home in the desktop (`Landing.GameHome`): one
  window, where every way into the game leads — the Retro Games folder, the
  catalogue, its channel, its results. Ways to play each mode, who is playing
  it now, who is winning and what its channel says, read from the database on
  every request — the part of the page that is new every day.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Landing.ArcadeHome
  import RetroHexChatWeb.Components.UI.Landing.GameCards
  import RetroHexChatWeb.Components.UI.Landing.GameHome

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Arcade
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Challenges
  alias RetroHexChat.Games.Ratings
  alias RetroHexChat.Games.Results

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  # A search result cuts a title at about 70 characters, so the longest form
  # that fits wins: the site's name goes when a game's name is long.
  @title_limit 70
  @recent_plays 10

  @impl RetroHexChatWeb.Site.Page
  def load(%{"slug" => slug}, ctx) do
    case GameCatalog.get(slug) do
      {:ok, game} -> load_game(game, ctx)
      :error -> :not_found
    end
  end

  defp load_game(game, ctx) do
    path = GameCatalog.page_path(game)

    {:ok,
     %{
       active_page: :games,
       game: game,
       path: path,
       play_path: play_path(game, ctx),
       visitor: ctx.visitor?,
       how_to_play_path: PublicPages.help_topic_path(game.help_topic),
       windows: windows(game, ctx),
       canonical_path: path,
       og_image: og_image(game),
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), PublicPages.localized_path("/")},
           {dgettext("landing", "Games"), PublicPages.localized_path("/games")},
           {game.name, PublicPages.localized_path(path)}
         ]),
         SEO.video_game_json_ld(game, path, matches_played(game))
       ],
       page_title: title(game),
       page_description: SEO.meta_description("#{game.tagline} — #{game.description}")
     }}
  end

  # A Retro Game is one window, its home. An arcade game's home is the same
  # window with less in it — nobody to play with and no result to rank, only
  # who started it — and the games beside it.
  defp windows(%{kind: :multiplayer, id: game_id} = game, ctx) do
    channel = Catalog.channel_name(game_id)
    # A one-player game is ranked on runs played alone, and has no computer.
    alone = Catalog.solo_only?(game_id)
    origin = if alone, do: "solo", else: "p2p"
    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)
    challenge = Challenges.for_week(game_id, Date.utc_today())
    week_count = Results.count_since(game_id, week_ago)
    playing_now = Activity.playing_in(game_id)

    [
      Window.new("game", game.name, :game_icon,
        icon_attrs: %{game_id: game.id},
        width: 820,
        body: &game_home/1,
        status: [
          dngettext(
            "landing",
            "%{count} game played this week",
            "%{count} games played this week",
            week_count,
            count: week_count
          ),
          dngettext(
            "landing",
            "%{count} playing now",
            "%{count} playing now",
            length(playing_now),
            count: length(playing_now)
          )
        ],
        assigns:
          put_nick_locales(%{
            ways: ways(game),
            sign_in_path: play_path(game, ctx),
            you: your_record(game_id, ctx),
            identified: Map.get(ctx, :identified?, false),
            register_path: PublicPages.localized_path("/chat/help/nickserv"),
            channel: channel,
            channel_path: Paths.chat_path(channel),
            alone: alone,
            ranking: if(Catalog.ranking(game_id) == :versus, do: :wins, else: :best),
            week:
              Results.standings(game_id, modes: true, origin: origin, since: week_ago, limit: 5),
            best:
              if(alone,
                do: Results.standings(game_id, modes: true, origin: "solo", limit: 5),
                else: []
              ),
            ratings: Ratings.top(game_id, 5),
            playing_now: playing_now,
            live: Activity.live_matches(game_id),
            challenge: challenge,
            challenge_leader: Challenges.leader(challenge),
            computer:
              if(alone,
                do: [],
                else:
                  Results.standings(game_id,
                    modes: true,
                    origin: "ai",
                    difficulty: "hard",
                    limit: 3
                  )
              ),
            recent: Results.recent(game_id, 6),
            chatter: Archive.recent(channel, 5),
            week_count: week_count
          })
      )
    ]
  end

  defp windows(%{kind: :arcade, id: game_id} = game, ctx) do
    channel = Arcade.channel_name(game_id)
    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)
    week_count = Arcade.play_count_since(game_id, week_ago)

    [
      Window.new("game", game.name, :game_icon,
        icon_attrs: %{game_id: game.id},
        width: 880,
        body: &arcade_home/1,
        status: [
          kind_label(game),
          dgettext("landing", "Free, in the browser"),
          dngettext(
            "landing",
            "%{count} game played this week",
            "%{count} games played this week",
            week_count,
            count: week_count
          )
        ],
        assigns:
          put_play_locales(%{
            you: your_plays(game_id, ctx),
            identified: Map.get(ctx, :identified?, false),
            register_path: PublicPages.localized_path("/chat/help/nickserv"),
            channel: channel,
            channel_path: Paths.chat_path(channel),
            recent: Arcade.recent_plays(game_id, @recent_plays),
            week: Arcade.most_played(game_id, week_ago, 5),
            all_time: Arcade.most_played(game_id, ~U[2000-01-01 00:00:00Z], 5),
            chatter: Archive.recent(channel, 5),
            week_count: week_count
          })
      ),
      Window.new("more-games", dgettext("landing", "More games"), :icon_joystick,
        width: 360,
        body: &game_card_list/1,
        assigns: %{
          heading_id: "more-games-heading",
          cards: game |> GameCatalog.related() |> Enum.map(&card/1),
          columns: "grid-cols-2",
          catalogue_path: PublicPages.localized_path("/games")
        }
      )
    ]
  end

  # Every nickname the home names — standings, ratings, matches, the channel's
  # last lines, who is playing — in one lookup, for the flag before each name.
  defp put_nick_locales(assigns) do
    cards = assigns.recent ++ ((assigns.you && assigns.you.recent) || [])

    nicks =
      Enum.map(assigns.week ++ assigns.computer ++ assigns.ratings, & &1.nickname) ++
        Enum.flat_map(cards, &[&1.p1_nickname, &1.p2_nickname]) ++
        Enum.map(assigns.chatter, & &1.author) ++
        assigns.playing_now ++
        List.wrap(assigns.challenge_leader && assigns.challenge_leader.nickname)

    Map.put(assigns, :nick_locales, NickLocales.for_nicks(nicks))
  end

  defp put_play_locales(assigns) do
    nicks =
      Enum.map(assigns.recent ++ assigns.week ++ assigns.all_time, & &1.nickname) ++
        Enum.map(assigns.chatter, & &1.author)

    Map.put(assigns, :nick_locales, NickLocales.for_nicks(nicks))
  end

  @doc """
  Whether who is playing the game of a loaded home, or which of its matches
  may be watched, is no longer what the page shows — the one part of it that
  moves with presence rather than with a recorded match.
  """
  @spec live_changed?(map()) :: boolean()
  def live_changed?(%{game: %{kind: :multiplayer, id: game_id}, windows: [home | _rest]}) do
    shown = Map.take(home.assigns, [:playing_now, :live])
    now = %{playing_now: Activity.playing_in(game_id), live: Activity.live_matches(game_id)}
    shown != now
  end

  def live_changed?(_loaded), do: false

  # The reader's own record — private matches included — so only for a
  # nickname this session has proved: holding somebody's registered nickname
  # without their password shows nothing of theirs.
  defp your_record(game_id, %{identified?: true, nickname: nickname}) when is_binary(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, player_id} -> Results.player_record(game_id, player_id)
      _unregistered -> nil
    end
  end

  defp your_record(_game_id, _ctx), do: nil

  defp your_plays(game_id, %{identified?: true, nickname: nickname}) when is_binary(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, player_id} -> Arcade.player_plays(game_id, player_id)
      _unregistered -> nil
    end
  end

  defp your_plays(_game_id, _ctx), do: nil

  # One way in per mode, the game itself first. Each opens in a tab of its
  # own: against the computer at the game's address, and a match room —
  # whose link is handed to a friend — at the same address asking for one.
  defp ways(game) do
    standard = %{id: game.id, name: game.name, tagline: game.tagline}

    for mode <- [standard | game.modes] do
      Map.merge(mode, %{
        play_path: Paths.play_path(mode.id),
        link_path: Paths.play_path(mode.id) <> "?match=new"
      })
    end
  end

  defp matches_played(%{kind: :multiplayer, id: game_id}),
    do: Results.count_since(game_id, ~U[2000-01-01 00:00:00Z])

  # An arcade game keeps no matches; the times it was started stand for them.
  defp matches_played(%{kind: :arcade, id: game_id}),
    do: Arcade.play_count_since(game_id, ~U[2000-01-01 00:00:00Z])

  # A visitor's Play asks for an account first, naming games, and comes back
  # to the game once they have one. A member whose nickname is not identified
  # is asked by the Arcade itself, which knows by then.
  defp play_path(game, %{visitor?: true}),
    do: Paths.visitor_sign_in_path(:games, GameCatalog.play_path(game))

  defp play_path(game, _ctx), do: GameCatalog.play_path(game)

  defp card(game),
    do: %{game: game, path: PublicPages.localized_path(GameCatalog.page_path(game))}

  defp kind_label(%{kind: :arcade}), do: dgettext("landing", "Arcade")

  # A game with a classic of its own leads its title with the classic's name
  # in the reader's language: someone looks for "paciência", not for the game.
  defp title(game) do
    name =
      case kind_of_game(game) do
        nil -> game.name
        kind -> "#{kind}: #{game.name}"
      end

    candidates = [
      dgettext("landing", "Play %{name} in your browser — Retro Hex Chat", name: name),
      dgettext("landing", "Play %{name} in your browser", name: name)
    ]

    Enum.find(candidates, List.last(candidates), &(String.length(&1) <= @title_limit))
  end

  # The words a search uses for a game with a classic of its own: someone looks
  # for "paciência" or "solitario", not for the game's name.
  defp kind_of_game(%{id: id}) when id in ~w(hex_solitaire hex_solitaire_draw3),
    do: dgettext("landing", "Klondike solitaire")

  defp kind_of_game(%{id: "hex_freecell"}), do: dgettext("landing", "FreeCell solitaire")

  defp kind_of_game(%{id: id}) when id in ~w(hex_spider hex_spider_2suits hex_spider_4suits),
    do: dgettext("landing", "Spider solitaire")

  defp kind_of_game(_game), do: nil

  defp og_image(%{screenshot: nil}), do: SEO.social_image()

  defp og_image(%{screenshot: shot} = game) do
    %{
      url: SEO.site_url(shot.og_path),
      width: shot.og_width,
      height: shot.og_height,
      type: "image/jpeg",
      alt: dgettext("landing", "Screenshot of %{name}", name: game.name)
    }
  end
end
