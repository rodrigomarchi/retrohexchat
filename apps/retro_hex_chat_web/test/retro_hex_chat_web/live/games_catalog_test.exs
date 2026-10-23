defmodule RetroHexChatWeb.GamesCatalogTest do
  @moduledoc """
  The public games catalogue: a page per game, found by search engines and
  shared as itself, and a way in that never leaves the page.

  The generic landing checks — one h1, the taskbar, the lightweight bundle, no
  link to /connect, a unique title and description — run over these pages from
  `Site.PagesTest`; what is asserted here is what is particular to a game.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Arcade.Queries, as: ArcadeQueries
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Queries, as: GameQueries
  alias RetroHexChat.Games.Schema.GameRating
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.I18n.Locales
  alias RetroHexChatWeb.LiveMatchPages
  alias RetroHexChatWeb.Site.Head
  alias RetroHexChatWeb.Site.Pages

  defp document(conn, path),
    do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp meta(document, selector) do
    document |> Floki.find(selector) |> Floki.attribute("content") |> List.first()
  end

  defp json_ld(document, type) do
    document
    |> Floki.find(~s(script[type="application/ld+json"]))
    |> Enum.map(&(&1 |> elem(2) |> hd() |> String.trim() |> Jason.decode!()))
    |> Enum.find(&(&1["@type"] == type))
  end

  # The head a game's page is sent with, from the same load and head the
  # desktop builds it from, in `locale`.
  defp game_head(slug, locale) do
    RetroHexChatWeb.I18n.put_locale(locale)
    {:ok, loaded} = Pages.Game.load(%{"slug" => slug}, %{locale: locale, visitor?: true})
    Head.from_page(loaded)
  after
    RetroHexChatWeb.I18n.put_locale(nil)
  end

  defp escaped(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp check_titles(locale) do
    heads =
      for slug <- GameCatalog.slugs() do
        head = game_head(slug, locale)
        page = "#{locale} #{slug}"
        # Measured as the document carries it, the way the rendered page was.
        assert String.length(escaped(head.title)) <= 70,
               "#{page} title is too long: #{head.title}"

        assert String.length(head.description) <= 170, "#{page} description is too long"
        head
      end

    assert heads |> Enum.map(& &1.title) |> Enum.uniq() |> length() == length(heads),
           "two game pages share a title (#{locale})"

    assert heads |> Enum.map(& &1.description) |> Enum.uniq() |> length() == length(heads),
           "two game pages share a description (#{locale})"
  end

  describe "/games" do
    test "links every game in the catalogue to its page", %{conn: conn} do
      hrefs = conn |> document("/games") |> Floki.find("a") |> Floki.attribute("href")

      for slug <- GameCatalog.slugs() do
        assert "/games/#{slug}" in hrefs, "the catalogue does not link #{slug}"
      end
    end

    test "a localized catalogue links the localized game pages", %{conn: conn} do
      hrefs = conn |> document("/pt-BR/games") |> Floki.find("a") |> Floki.attribute("href")

      assert "/pt-BR/games/doom-shareware" in hrefs
    end
  end

  describe "a game's page" do
    test "is titled for the search it answers and canonical to itself", %{conn: conn} do
      document = document(conn, "/games/doom-shareware")

      assert document |> Floki.find("title") |> Floki.text() =~
               "Play DOOM: Knee-Deep in the Dead in your browser"

      assert document |> Floki.find(~s(link[rel="canonical"])) |> Floki.attribute("href") ==
               ["https://retrohexchat.app/games/doom-shareware"]

      hreflangs =
        document |> Floki.find(~s(link[rel="alternate"])) |> Floki.attribute("hreflang")

      assert "pt-BR" in hreflangs
      assert "x-default" in hreflangs
    end

    test "is shared with its own screenshot", %{conn: conn} do
      {:ok, game} = GameCatalog.get("doom-shareware")
      document = document(conn, "/games/doom-shareware")

      # A share card is JPEG at the size platforms crop to: LinkedIn and
      # WhatsApp do not reliably show the page's WebP.
      assert meta(document, ~s(meta[property="og:image"])) =~
               "https://retrohexchat.app/images/games/og/doom-shareware.jpg"

      assert meta(document, ~s(meta[property="og:image:type"])) == "image/jpeg"

      assert meta(document, ~s(meta[property="og:image:width"])) ==
               to_string(game.screenshot.og_width)

      assert meta(document, ~s(meta[name="twitter:image"])) =~ "og/doom-shareware.jpg"
    end

    test "states what it is as VideoGame structured data", %{conn: conn} do
      game = conn |> document("/games/doom-shareware") |> json_ld("VideoGame")

      assert game["name"] == "DOOM: Knee-Deep in the Dead"
      assert game["url"] == "https://retrohexchat.app/games/doom-shareware"
      assert game["playMode"] == "SinglePlayer"
      assert game["image"] =~ "doom-shareware.webp"
    end

    # The page is the same sheet the in-app Arcade opens on: what the game is,
    # every key and the tips, read before signing in.
    test "shows the game's whole sheet", %{conn: conn} do
      page = conn |> get("/games/doom-shareware") |> html_response(200)
      document = Floki.parse_document!(page)
      {:ok, game} = GameCatalog.get_arcade("doom_shareware")

      assert page =~ "the game that launched the FPS genre into the mainstream"
      tip = game.tips |> hd() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
      assert page =~ tip

      assert length(Floki.find(document, ~s([data-testid="game-controls"] tbody tr))) ==
               length(game.keys)
    end

    test "playing goes through the sign-in window, which lands on the game", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/games/doom-shareware")

      # The arcade opens inside the chat, on this game, once the reader has a
      # nickname: the public page never sends them off the site.
      assert play_href(view) == "/connect?return_to=%2F%3Farcade%3Ddoom_shareware&signup=games"
    end

    test "a multiplayer game is one window, its home, with a way in per mode", %{conn: conn} do
      {:ok, view, html} = live(conn, "/games/hex-tennis")

      assert html =~ "Quick Match"
      assert html =~ "Sudden Death"
      assert has_element?(view, ~s([data-testid="game-home"]))
      assert has_element?(view, ~s([data-testid="game-way-hex_tennis"]))
      assert has_element?(view, ~s([data-testid="game-way-hex_tennis_quick"]))

      # A visitor's every way in asks for an account and lands on the game.
      assert play_href(view, "hex_tennis_quick") ==
               "/connect?return_to=%2Fplay%2Fhex_tennis&signup=games"

      refute has_element?(view, ~s([data-testid="game-lfg"]))
      refute has_element?(view, ~s([data-testid="game-invite"]))

      # Every tab is in the HTML a crawler reads.
      for tab <- ~w(play live ranking channel) do
        assert has_element?(view, ~s([data-testid="game-home-#{tab}"]))
      end

      assert conn |> document("/games/hex-tennis") |> json_ld("VideoGame") |> Map.get("playMode") ==
               "MultiPlayer"
    end

    test "a member plays a mode beside the desktop, and How to play is its own topic",
         %{conn: conn} do
      gamer = player("gamer#{System.unique_integer([:positive])}")

      {:ok, view, _html} =
        conn |> chat_conn(gamer.nickname, pre_identified: true) |> live("/games/hex-tennis")

      play =
        view
        |> element(~s([data-testid="game-way-hex_tennis_quick"] [data-testid="game-play"]))
        |> render()
        |> Floki.parse_fragment!()

      assert Floki.attribute(play, "href") == ["/play/hex_tennis_quick"]
      assert Floki.attribute(play, "target") == ["_blank"]
      assert Floki.attribute(play, "data-confirm-tab") == ["surface"]
      refute render(view) =~ "pick a nickname"

      assert has_element?(
               view,
               ~s([data-testid="game-way-hex_tennis_quick"] [data-testid="game-lfg"][phx-value-game="hex_tennis_quick"])
             )

      assert has_element?(
               view,
               ~s([data-testid="game-challenge-form"][phx-submit="game_home_challenge"])
             )

      assert view
             |> element(
               ~s([data-testid="game-way-hex_tennis_quick"] [data-testid="game-match-link"])
             )
             |> render() =~ "/play/hex_tennis_quick?match=new"

      assert view
             |> element(~s([data-testid="game-how-to-play"]))
             |> render() =~ "/chat/help/feature-hex-tennis"
    end

    test "every game's How to play is a topic that exists" do
      for game <- GameCatalog.list() do
        assert HelpTopics.get_topic(game.help_topic),
               "#{game.slug} points at #{game.help_topic}"
      end
    end

    test "a slug that names no game answers 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, "/games/no-such-game") end
      # A mode is part of its game's page, never a page of its own.
      assert_error_sent 404, fn -> get(conn, "/games/hex-tennis-quick") end
    end
  end

  describe "a Retro Game's community" do
    # Written straight to the ledger: recording through `Games.Results` would
    # also announce the match in #hex-pong, a channel process this async test
    # does not own.
    defp record_match(host, guest, {p1_score, p2_score, outcome}, token) do
      now = DateTime.utc_now()

      {:ok, _row} =
        GameQueries.insert(%{
          game_id: "hex_pong",
          base_id: "hex_pong",
          origin: "p2p",
          p1_id: host.id,
          p1_nickname: host.nickname,
          p2_id: guest.id,
          p2_nickname: guest.nickname,
          p1_score: p1_score,
          p2_score: p2_score,
          outcome: outcome,
          ranked: true,
          duration_ms: 120_000,
          started_at: DateTime.add(now, -120, :second),
          finished_at: now,
          lobby_token: token
        })
    end

    defp player(nickname) do
      {:ok, nick} =
        RetroHexChat.Repo.insert(%RegisteredNick{
          nickname: nickname,
          password_hash: "x",
          registered_at: DateTime.utc_now(),
          last_seen_at: DateTime.utc_now()
        })

      %{id: nick.id, nickname: nickname}
    end

    # What a crawler reads is the first response: the ranking and the latest
    # matches have to be in it, not arrive over the socket.
    test "the ranking and the latest matches are in the page a visitor is sent", %{conn: conn} do
      ana = player("ana#{System.unique_integer([:positive])}")
      beto = player("beto#{System.unique_integer([:positive])}")
      record_match(ana, beto, {11, 4, "p1"}, "hub-1")
      record_match(beto, ana, {6, 11, "p2"}, "hub-2")

      document = document(conn, "/games/hex-pong")

      assert [week] = Floki.find(document, ~s([data-testid="game-community-week"]))
      assert Floki.text(week) =~ ana.nickname
      assert Floki.text(week) =~ "2 wins"

      assert document |> Floki.find(~s([data-testid="game-community-recent"])) |> Floki.text() =~
               "#{ana.nickname} 11 × 4 #{beto.nickname}"

      assert [channel] = Floki.find(document, ~s([data-testid="game-community-channel"]))
      assert Floki.attribute(channel, "href") == ["/c/hex-pong"]

      assert json_ld(document, "VideoGame")["interactionStatistic"]["userInteractionCount"] == 2
    end

    test "a versus game ranks its players by rating", %{conn: conn} do
      ana = player("ana#{System.unique_integer([:positive])}")

      RetroHexChat.Repo.insert!(%GameRating{
        base_id: "hex_pong",
        player_id: ana.id,
        rating: 1234,
        matches: 3
      })

      ratings =
        conn
        |> document("/games/hex-pong")
        |> Floki.find(~s([data-testid="game-community-ratings"]))
        |> Floki.text()

      assert ratings =~ ana.nickname
      assert ratings =~ "1234"
    end

    test "a match being played in the open is on the page, to watch", %{conn: conn} do
      ana = player("ana#{System.unique_integer([:positive])}")
      beto = player("beto#{System.unique_integer([:positive])}")

      {:ok, %{token: token}} =
        Lobby.create_open_session(ana.id, metadata: %{"game_id" => "hex_pong"})

      LiveMatchPages.playing([ana.nickname, beto.nickname], "hex_pong", token)

      assert [link] =
               conn
               |> document("/games/hex-pong")
               |> Floki.find(~s([data-testid="game-community-live"] [data-token="#{token}"]))

      assert Floki.attribute(link, "href") == ["/watch/#{token}"]
      # Watching is a screen of its own, beside the desktop.
      assert Floki.attribute(link, "target") == ["_blank"]
      assert Floki.text(link) =~ ana.nickname
    end

    test "the You tab is the reader's own record in the game", %{conn: conn} do
      ana = player("ana#{System.unique_integer([:positive])}")
      beto = player("beto#{System.unique_integer([:positive])}")
      record_match(ana, beto, {11, 4, "p1"}, "you-1")

      RetroHexChat.Repo.insert!(%GameRating{
        base_id: "hex_pong",
        player_id: ana.id,
        rating: 1216,
        matches: 1,
        wins: 1
      })

      {:ok, view, _html} =
        conn |> chat_conn(ana.nickname, pre_identified: true) |> live("/games/hex-pong")

      rating = view |> element(~s([data-testid="game-you-rating"])) |> render()
      assert rating =~ "1216"
      assert rating =~ "Place 1 of 1"

      assert view |> element(~s([data-testid="game-you-totals"])) |> render() =~ "Against people"

      assert view |> element(~s([data-testid="game-you-recent"])) |> render() =~
               "#{ana.nickname} 11 × 4 #{beto.nickname}"
    end

    # The You tab includes private matches, so it is shown only to a session
    # that proved the nickname: holding it is not enough.
    test "a registered nickname this session has not proved sees no record", %{conn: conn} do
      ana = player("ana#{System.unique_integer([:positive])}")
      beto = player("beto#{System.unique_integer([:positive])}")
      record_match(ana, beto, {11, 4, "p1"}, "you-private")

      {:ok, view, _html} =
        conn |> chat_conn(ana.nickname, pre_identified: false) |> live("/games/hex-pong")

      assert has_element?(view, ~s([data-testid="game-you-unranked"]))
      refute has_element?(view, ~s([data-testid="game-you-recent"]))
      refute has_element?(view, ~s([data-testid="game-lfg"]))
      assert has_element?(view, ~s([data-testid="game-identify"]))
    end

    test "a reader the ranking does not know is told how to enter it", %{conn: conn} do
      {:ok, visitor_view, _html} = live(conn, "/games/hex-pong")
      assert has_element?(visitor_view, ~s([data-testid="game-you-unranked"]))
      assert has_element?(visitor_view, ~s([data-testid="game-you-sign-in"]))

      {:ok, guest_view, _html} =
        build_conn() |> chat_conn("unreg#{uid()}") |> live("/games/hex-pong")

      assert has_element?(guest_view, ~s([data-testid="game-you-unranked"]))

      assert has_element?(
               guest_view,
               ~s([data-testid="game-you-register"][href="/chat/help/nickserv"])
             )

      someone = player("new#{System.unique_integer([:positive])}")

      {:ok, new_view, _html} =
        build_conn()
        |> chat_conn(someone.nickname, pre_identified: true)
        |> live("/games/hex-pong")

      assert has_element?(new_view, ~s([data-testid="game-you-none"]))
    end

    # Open while matches end and people start playing, the home follows:
    # no reopening to see the result that just came in.
    test "an open home follows its game's results and who is playing", %{conn: conn} do
      ana = player("ana#{System.unique_integer([:positive])}")
      beto = player("beto#{System.unique_integer([:positive])}")
      {:ok, view, _html} = conn |> chat_conn(ana.nickname) |> live("/games/hex-pong")

      record_match(ana, beto, {11, 2, "p1"}, "live-1")
      send(view.pid, {:game_result_recorded, %{base_id: "hex_pong"}})

      assert view |> element(~s([data-testid="game-community-recent"])) |> render() =~
               "#{ana.nickname} 11 × 2 #{beto.nickname}"

      {:ok, %{token: token}} =
        Lobby.create_open_session(ana.id, metadata: %{"game_id" => "hex_pong"})

      LiveMatchPages.playing([ana.nickname, beto.nickname], "hex_pong", token)
      send(view.pid, :refresh_games_playing)

      assert view |> element(~s([data-testid="game-community-playing"])) |> render() =~
               beto.nickname
    end
  end

  describe "an arcade game's home" do
    defp arcade_player(nickname) do
      {:ok, nick} =
        RetroHexChat.Repo.insert(%RegisteredNick{
          nickname: nickname,
          password_hash: "x",
          registered_at: DateTime.utc_now(),
          last_seen_at: DateTime.utc_now()
        })

      %{id: nick.id, nickname: nickname}
    end

    # A play is a session somebody pressed Play in. Written straight to the
    # sessions: starting one through `Arcade` would also announce it in a
    # channel process this async test does not own.
    defp played(player, game_id, minutes_ago) do
      {:ok, _session} =
        ArcadeQueries.insert_session(%{
          token: "t#{System.unique_integer([:positive])}",
          creator_id: player.id,
          status: "playing",
          game_id: game_id,
          game_started_at: DateTime.add(DateTime.utc_now(), -minutes_ago, :minute)
        })
    end

    test "who played it and who plays it most are in the page a visitor is sent", %{conn: conn} do
      ana = arcade_player("ana#{System.unique_integer([:positive])}")
      beto = arcade_player("beto#{System.unique_integer([:positive])}")
      played(ana, "hacx", 30)
      played(ana, "hacx", 20)
      played(beto, "hacx", 5)

      document = document(conn, "/games/hacx")

      assert [recent] = Floki.find(document, ~s([data-testid="arcade-home-recent"]))
      [first, _second, _third] = Floki.find(recent, "li")
      assert Floki.text(first) =~ beto.nickname

      assert [week] = Floki.find(document, ~s([data-testid="arcade-home-week"]))
      [top | _rest] = Floki.find(week, "li")
      assert Floki.find(top, "strong") |> Floki.text() == ana.nickname
      assert Floki.text(top) =~ "started 2 times"

      assert [channel] = Floki.find(document, ~s([data-testid="game-community-channel"]))
      assert Floki.attribute(channel, "href") == ["/c/hacx"]

      assert document |> Floki.find(~s([data-testid="game-community-count"])) |> Floki.text() =~
               "3 games played this week"

      # Still the game's whole sheet, under Play.
      assert [_] =
               Floki.find(
                 document,
                 ~s([data-testid="game-home-play"] [data-testid="game-controls"])
               )

      # The times it was started stand for the matches a Retro Game counts.
      assert json_ld(document, "VideoGame")["interactionStatistic"]["userInteractionCount"] == 3
    end

    test "a game nobody played says so", %{conn: conn} do
      document = document(conn, "/games/scummvm-soltys")
      assert [_] = Floki.find(document, ~s([data-testid="arcade-home-recent-none"]))
      refute json_ld(document, "VideoGame")["interactionStatistic"]
    end

    test "the You tab counts the reader's own plays, for a proved nickname only", %{conn: conn} do
      ana = arcade_player("ana#{System.unique_integer([:positive])}")
      played(ana, "rekkr", 90)
      played(ana, "rekkr", 10)

      {:ok, view, _html} =
        conn |> chat_conn(ana.nickname, pre_identified: true) |> live("/games/rekkr")

      assert view |> element(~s([data-testid="game-you-plays"])) |> render() =~
               "You have started this game 2 times."

      {:ok, unproved, _html} =
        build_conn() |> chat_conn(ana.nickname, pre_identified: false) |> live("/games/rekkr")

      assert has_element?(unproved, ~s([data-testid="game-you-unranked"]))
    end

    test "an open home follows the players who start its game", %{conn: conn} do
      ana = arcade_player("ana#{System.unique_integer([:positive])}")
      {:ok, view, _html} = conn |> chat_conn(ana.nickname) |> live("/games/chex-quest")
      assert has_element?(view, ~s([data-testid="arcade-home-recent-none"]))

      played(ana, "chex_quest", 0)
      send(view.pid, {:arcade_play_started, %{game_id: "chex_quest"}})

      assert view |> element(~s([data-testid="arcade-home-recent"])) |> render() =~ ana.nickname
    end
  end

  describe "the home page" do
    test "lists every Retro Game, each leading to its home", %{conn: conn} do
      document = document(conn, "/")

      for game <- Catalog.base_games() do
        assert [link] = Floki.find(document, ~s([data-testid="index-game-#{game.id}"]))

        assert Floki.attribute(link, "href") == [Paths.game_page_path(game.id)]
      end
    end
  end

  describe "every game's page" do
    # The landing suite checks one game page in English; every game has a name
    # of its own length in every language, and a title or description a search
    # result cuts is one the page loses, so each is checked here — on the head
    # each page is built with, since rendering every game in every language
    # costs hundreds of full pages. One page per language, a different game
    # each, is then fetched to prove the page says what that head says.
    test "has a title and description that fit a search result, unlike any other",
         %{conn: conn} do
      slugs = GameCatalog.slugs()

      Locales.enabled()
      |> Enum.with_index()
      |> Enum.each(fn {locale, index} ->
        check_titles(locale.code)

        slug = Enum.at(slugs, rem(index, length(slugs)))

        prefix =
          if locale.code == RetroHexChatWeb.I18n.default_locale(),
            do: "",
            else: "/#{locale.bcp47}"

        path = "#{prefix}/games/#{slug}"
        head = game_head(slug, locale.code)
        document = document(conn, path)

        assert document |> Floki.find("title") |> Floki.text() |> String.trim() ==
                 escaped(head.title),
               "#{path} is not titled by its head"

        assert meta(document, ~s(meta[name="description"])) == head.description,
               "#{path} is not described by its head"

        assert document |> Floki.find("h1") |> length() == 1, "#{path} has more than one h1"
      end)
    end
  end

  describe "a game's page in another language" do
    test "links its languages to its own translations, not to the catalogue", %{conn: conn} do
      hrefs =
        conn
        |> document("/pt-BR/games/doom-shareware")
        |> Floki.find("a")
        |> Floki.attribute("href")

      assert "/de/games/doom-shareware" in hrefs
      refute "/de/games" in hrefs
    end

    test "links the menus in its own language, without a redirect", %{conn: conn} do
      hrefs =
        conn
        |> document("/pt-BR/games/doom-shareware")
        |> Floki.find("a")
        |> Floki.attribute("href")

      assert "/pt-BR/features" in hrefs
      assert "/pt-BR/games" in hrefs
      refute "/features" in hrefs
    end

    test "names itself, not the English page, in its structured data", %{conn: conn} do
      document = document(conn, "/pt-BR/games/doom-shareware")
      game = json_ld(document, "VideoGame")

      assert game["url"] == "https://retrohexchat.app/pt-BR/games/doom-shareware"
      assert game["inLanguage"] == "pt-BR"
      assert game["applicationCategory"] == "GameApplication"
    end
  end

  describe "the meta description" do
    test "is cut at a word, never inside one" do
      long = String.duplicate("word ", 40) <> "ending"
      cut = RetroHexChatWeb.SEO.meta_description(long)

      assert String.length(cut) <= 155
      assert String.ends_with?(cut, "word…")
      assert RetroHexChatWeb.SEO.meta_description("short") == "short"
    end
  end

  describe "every game" do
    test "has a screenshot captured for it" do
      missing = for game <- GameCatalog.list(), game.screenshot == nil, do: game.slug

      assert missing == [], "run `make games.shots ONLY=#{Enum.join(missing, ",")}`"
    end
  end

  describe "the help page of a game" do
    test "links to the game's catalogue page", %{conn: conn} do
      document = document(conn, "/chat/help/feature-arcade-doom-shareware")

      assert document
             |> Floki.find(~s([data-testid="help-catalogue-link"] a))
             |> Floki.attribute("href") == ["/games/doom-shareware"]
    end

    test "a Retro Game's help page links to its home", %{conn: conn} do
      document = document(conn, "/chat/help/feature-hex-tennis")

      assert document
             |> Floki.find(~s([data-testid="help-catalogue-link"] a))
             |> Floki.attribute("href") == ["/games/hex-tennis"]
    end

    test "the Arcade's and an engine's help pages link to the whole catalogue", %{conn: conn} do
      for topic <- ~w(feature-arcade feature-arcade-doom) do
        assert conn
               |> document("/chat/help/#{topic}")
               |> Floki.find(~s([data-testid="help-catalogue-link"] a))
               |> Floki.attribute("href") == ["/games"]
      end
    end

    # The lists are built from the catalogue, so the See Also under them must
    # know which topics they already link.
    test "a game listed in the help is not linked again under See Also", %{conn: conn} do
      for {topic, game_topic} <- [
            {"feature-retro-games", "feature-hex-tennis"},
            {"feature-arcade", "feature-arcade-doom-shareware"}
          ] do
        document = document(conn, "/chat/help/#{topic}")
        link = ~s(a[href="/chat/help/#{game_topic}"])

        assert [_ | _] = Floki.find(document, ~s([data-testid^="help-games-"] #{link}))
        assert Floki.find(document, ~s([data-testid="help-see-also"] #{link})) == []
      end
    end

    test "a topic that is not about games links nowhere new", %{conn: conn} do
      document = document(conn, "/chat/help/nickserv")

      assert Floki.find(document, ~s([data-testid="help-catalogue-link"])) == []
    end

    # The list is read from the catalogue: every game is in it, under its
    # engine, and its name opens its page.
    test "the Arcade's help lists every game, each linking to its page", %{conn: conn} do
      document = document(conn, "/chat/help/feature-arcade")

      for group <- GameCatalog.arcade_groups(), game <- group.games do
        assert [_] =
                 Floki.find(
                   document,
                   ~s([data-testid="help-games-#{group.engine}"] a[href="/games/#{game.slug}"])
                 )
      end
    end
  end

  describe "the sitemap" do
    test "offers the catalogue and every game's page", %{conn: conn} do
      index = conn |> get("/sitemap.xml") |> response(200)

      urls =
        ~r{<loc>([^<]+)</loc>}
        |> Regex.scan(index)
        |> Enum.map(&List.last/1)
        |> Enum.map(&URI.parse(&1).path)
        # The game pages are among the public pages; the whole sitemap is
        # walked by `SEO.PublicUrlsTest`.
        |> Enum.filter(&String.starts_with?(&1, "/sitemaps/public-"))
        |> Enum.map(&(conn |> get(&1) |> response(200)))
        |> Enum.join()

      assert urls =~ "https://retrohexchat.app/games</loc>"
      assert urls =~ "https://retrohexchat.app/pt-BR/games/doom-shareware"

      for slug <- GameCatalog.slugs() do
        assert urls =~ "https://retrohexchat.app/games/#{slug}</loc>", "sitemap misses #{slug}"
      end
    end
  end

  defp play_href(view, way \\ nil) do
    selector =
      if way,
        do: ~s([data-testid="game-way-#{way}"] [data-testid="game-play"]),
        else: ~s([data-testid="game-play"])

    view
    |> element(selector)
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.attribute("href")
    |> List.first()
    |> String.replace("&amp;", "&")
  end
end
