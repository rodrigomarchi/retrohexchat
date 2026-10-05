defmodule RetroHexChatWeb.GamesCatalogTest do
  @moduledoc """
  The public games catalogue: a page per game, found by search engines and
  shared as itself, and a way in that never leaves the page.

  The generic landing checks — one h1, the taskbar, the lightweight bundle, no
  link to /connect, a unique title and description — run over these pages from
  `LandingLiveTest`; what is asserted here is what is particular to a game.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChatWeb.GameCatalog

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

  defp check_titles(conn, prefix) do
    pages =
      for slug <- GameCatalog.slugs() do
        document = document(conn, "#{prefix}/games/#{slug}")
        title = document |> Floki.find("title") |> Floki.text() |> String.trim()
        description = meta(document, ~s(meta[name="description"]))

        assert String.length(title) <= 70, "#{slug} title is too long: #{title}"
        assert String.length(description) <= 170, "#{slug} description is too long"
        assert document |> Floki.find("h1") |> length() == 1, "#{slug} has more than one h1"

        {title, description}
      end

    assert pages |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == length(pages)
    assert pages |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == length(pages)
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

    # The help page is already indexed with the arcade's long prose; the
    # catalogue says what the game is in its own words, so a search engine is
    # never left to choose between two URLs saying the same thing.
    test "does not repeat the help page's prose", %{conn: conn} do
      help = conn |> get("/chat/help/feature-arcade-doom-shareware") |> html_response(200)
      page = conn |> get("/games/doom-shareware") |> html_response(200)

      opening = "the game that launched the FPS genre into the mainstream"
      assert help =~ opening
      refute page =~ opening
    end

    test "playing goes through the page's own Connect window, which lands on the game", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/games/doom-shareware")

      assert view
             |> element(~s([data-testid="game-play"][data-window-open="connect"]))
             |> has_element?()

      # The arcade opens inside the chat, on this game, once the reader has a
      # nickname: the public page never sends them off the site.
      assert html =~ ~s(name="return_to" value="/chat?arcade=doom_shareware")
    end

    test "a multiplayer game lists its modes and starts a match", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/games/hex-tennis")

      assert html =~ "Quick Match"
      assert html =~ "Sudden Death"
      assert html =~ ~s(name="return_to" value="/play/hex_tennis")

      assert conn |> document("/games/hex-tennis") |> json_ld("VideoGame") |> Map.get("playMode") ==
               "MultiPlayer"
    end

    test "a slug that names no game answers 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, "/games/no-such-game") end
      # A mode is part of its game's page, never a page of its own.
      assert_error_sent 404, fn -> get(conn, "/games/hex-tennis-quick") end
    end
  end

  describe "every game's page" do
    # The landing suite checks one game page in English; every game has a name
    # of its own length in every language, and a title or description a search
    # result cuts is one the page loses, so each is checked here.
    for prefix <- ["" | Enum.map(RetroHexChatWeb.SEO.localized_locale_segments(), &"/#{&1}")] do
      @prefix prefix
      test "has a title and description that fit a search result, unlike any other (#{prefix})",
           %{conn: conn} do
        check_titles(conn, @prefix)
      end
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

    test "a topic that is not a game links nowhere new", %{conn: conn} do
      document = document(conn, "/chat/help/feature-arcade-doom")

      assert Floki.find(document, ~s([data-testid="help-catalogue-link"])) == []
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
        |> Enum.map(&(conn |> get(&1) |> response(200)))
        |> Enum.join()

      assert urls =~ "https://retrohexchat.app/games</loc>"
      assert urls =~ "https://retrohexchat.app/pt-BR/games/doom-shareware"

      for slug <- GameCatalog.slugs() do
        assert urls =~ "https://retrohexchat.app/games/#{slug}</loc>", "sitemap misses #{slug}"
      end
    end
  end
end
