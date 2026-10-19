defmodule RetroHexChatWeb.Site.Pages.Game do
  @moduledoc """
  One game's public page: what it is, what it looks like, and the way in.

  This is the page a search for "play DOOM in the browser" should land on, so
  it says that in its title and shows the game itself. How to play in depth —
  every control, tips — stays in the in-app help, which this page links to
  rather than repeats.

  A Retro Game's page is also its community's front door: a window of who is
  winning, the latest matches and its channel's last lines, read from the
  database on every request — the part of the page that is new every day.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Landing.GameCards
  import RetroHexChatWeb.Components.UI.Landing.GameCommunity

  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Challenges
  alias RetroHexChat.Games.Ratings
  alias RetroHexChat.Games.Results

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  # A search result cuts a title at about 70 characters, so the longest form
  # that fits wins: the site's name goes when a game's name is long.
  @title_limit 70

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
       how_to_play_path: PublicPages.localized_path("/chat/help/#{game.help_topic}"),
       windows:
         Enum.reject(
           [
             Window.new("game", game.name, :game_icon,
               icon_attrs: %{game_id: game.id},
               width: 760,
               body: &game_detail/1,
               status: [kind_label(game), dgettext("landing", "Free, in the browser")]
             ),
             community_window(game),
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
           ],
           &is_nil/1
         ),
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

  # Only a Retro Game has a channel and a ledger; an arcade game has neither.
  defp community_window(%{kind: :multiplayer, id: game_id}) do
    channel = Catalog.channel_name(game_id)
    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)
    challenge = Challenges.for_week(game_id, Date.utc_today())

    Window.new("community", channel, :icon_chat,
      width: 360,
      body: &game_community/1,
      assigns: %{
        channel: channel,
        channel_path: Paths.chat_path(channel),
        ranking: if(Catalog.ranking(game_id) == :versus, do: :wins, else: :best),
        week: Results.standings(game_id, modes: true, since: week_ago, limit: 5),
        ratings: Ratings.top(game_id, 5),
        playing_now: Activity.playing_in(game_id),
        live: Activity.live_matches(game_id),
        challenge: challenge,
        challenge_leader: Challenges.leader(challenge),
        computer:
          Results.standings(game_id, modes: true, origin: "ai", difficulty: "hard", limit: 3),
        recent: Results.recent(game_id, 6),
        chatter: Archive.recent(channel, 5),
        week_count: Results.count_since(game_id, week_ago)
      }
    )
  end

  defp community_window(_arcade_game), do: nil

  defp matches_played(%{kind: :multiplayer, id: game_id}),
    do: Results.count_since(game_id, ~U[2000-01-01 00:00:00Z])

  defp matches_played(_arcade_game), do: nil

  # A visitor's Play asks for an account first, naming games, and comes back
  # to the game once they have one.
  defp play_path(game, %{visitor?: true}),
    do: Paths.visitor_sign_in_path(:games, GameCatalog.play_path(game))

  defp play_path(game, _ctx), do: GameCatalog.play_path(game)

  defp card(game),
    do: %{game: game, path: PublicPages.localized_path(GameCatalog.page_path(game))}

  defp kind_label(%{kind: :arcade}), do: dgettext("landing", "Solo arcade")

  defp kind_label(%{kind: :multiplayer}),
    do: dgettext("landing", "Multiplayer — or against the AI")

  defp title(game) do
    candidates = [
      dgettext("landing", "Play %{name} in your browser — Retro Hex Chat", name: game.name),
      dgettext("landing", "Play %{name} in your browser", name: game.name)
    ]

    Enum.find(candidates, List.last(candidates), &(String.length(&1) <= @title_limit))
  end

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
