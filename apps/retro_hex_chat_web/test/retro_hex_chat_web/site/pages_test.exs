defmodule RetroHexChatWeb.Site.PagesTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Components.UI.Site.Document
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.About
  alias RetroHexChatWeb.Site.Head
  alias RetroHexChatWeb.Site.Pages.Faq
  alias RetroHexChatWeb.Site.Registry

  @landing_pages [
    {"/", "hero-heading"},
    {"/how-it-works", "how-it-works-heading"},
    {"/features", "features-heading"},
    {"/games", "games-heading"},
    {"/games/doom-shareware", "game-heading"},
    {"/privacy", "privacy-heading"},
    {"/install", "install-heading"},
    {"/community", "community-heading"},
    {"/faq", "faq-heading"},
    {"/mirc-commands", "mirc-commands-heading"},
    {"/mirc-online", "mirc-online-heading"},
    {"/irc-chat", "irc-chat-heading"}
  ]

  describe "all landing pages" do
    for {path, heading_id} <- @landing_pages do
      test "GET #{path} renders successfully", %{conn: conn} do
        {:ok, _view, html} = live(conn, unquote(path))
        assert html =~ ~s(id="#{unquote(heading_id)}")
      end

      # Every check here reads the page's first response — the one a crawler
      # indexes and a reader's first paint draws — so it is fetched once.
      test "GET #{path} is a page of the one desktop", %{conn: conn} do
        path = unquote(path)
        heading_id = unquote(heading_id)
        body = conn |> get(path) |> html_response(200)
        document = Floki.parse_document!(body)

        # The page is read before the chat starts: the first paint loads the
        # desktop's small entry, which fetches the LiveSocket later.
        assert body =~ "/assets/js/desktop.js"
        refute body =~ "/assets/js/retrohex_content.js"
        refute body =~ "/assets/js/app.js"

        h1s = Floki.find(document, "h1")
        assert length(h1s) == 1
        assert Floki.attribute(h1s, "id") == [heading_id]
        h1_classes = h1s |> Floki.attribute("class") |> Enum.join(" ")
        refute h1_classes =~ "sr-only"

        assert body =~ ~s(rel="canonical" href="https://retrohexchat.app#{path}")

        head = page_head(path)

        assert document |> Floki.find("title") |> Floki.text() |> String.trim() ==
                 escaped(head.title),
               "#{path} is not titled by its head"

        assert document
               |> Floki.find(~s(meta[name="description"]))
               |> Floki.attribute("content") == [head.description],
               "#{path} is not described by its head"

        assert_sign_in_patches(document)
        assert_taskbar(document)
        assert_taskbar_buttons(document)
        assert_declared_windows(document, path, heading_id)
        assert_about(document, path)
      end
    end
  end

  # The sign-in window is one of the desktop's own windows: a page reaches it
  # by patching to /connect, so the chat behind it never reloads. A plain link
  # to it would throw the reader's desktop away to draw the same thing again.
  defp assert_sign_in_patches(document) do
    for link <- Floki.find(document, ~s(a[href^="/connect"])) do
      assert Floki.attribute(link, "data-phx-link") == ["patch"],
             "#{Floki.raw_html(link)} reloads the page"
    end
  end

  defp assert_taskbar(document) do
    assert Floki.find(document, ".desktop-taskbar") != []

    # The taskbar is the app's own, driven by the window manager rather than
    # a bespoke toggle — and the manager mounts on the shell root.
    assert Floki.find(document, "[data-window-manager]") != []
    assert Floki.find(document, "[data-window-start]") != []

    # Every page of the site is a window of the one desktop, and the Start
    # menu reaches each of them as a patch, never a page load.
    start_menu = Floki.find(document, "#chat-start-menu")
    assert start_menu != []
    hrefs = start_menu |> Floki.find("a") |> Floki.attribute("href")

    assert "/faq" in hrefs
    assert "/chat/help" in hrefs

    for page <- ["/", "/features", "/privacy", "/community"] do
      assert page in hrefs, "the Start menu lost the link to #{page}"
    end
  end

  # A visitor's home keeps its windows closed behind the chat; the desktop
  # icon that opens them is their way back, and their taskbar group comes
  # with them.
  defp assert_taskbar_buttons(document) do
    closed =
      document
      |> Floki.find(~s([data-window-group-open="false"] [data-window-id]))
      |> Floki.attribute("data-window-id")

    windows =
      document
      |> Floki.find("[data-window-id]")
      |> Floki.attribute("data-window-id")
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(closed))

    buttons =
      document
      |> Floki.find("[data-window-taskbar]")
      |> Floki.attribute("data-window-taskbar")
      |> MapSet.new()

    assert windows != MapSet.new()

    assert MapSet.equal?(windows, buttons),
           """
           A window with no taskbar button cannot be reopened once closed.

           windows without a button: #{inspect(MapSet.difference(windows, buttons))}
           buttons without a window: #{inspect(MapSet.difference(buttons, windows))}
           """
  end

  # The windows a page declares (`Site.Window`) are the windows it draws —
  # nothing drawn undeclared, nothing declared missing — and the first of
  # them, the one in front, says what the page is.
  defp assert_declared_windows(document, path, heading_id) do
    drawn =
      document
      |> Floki.find(~s([data-testid="site-windows"] [data-window-group="site"]))
      |> Floki.attribute("data-window-id")

    declared = for window <- page_windows(path), do: "site-" <> window.id

    assert drawn == declared

    [first | _rest] = Floki.find(document, ~s([data-window-group="site"]))
    assert Floki.find(first, "h1##{heading_id}") != []
    assert first |> Floki.find("p") |> Floki.text() |> String.trim() != ""
  end

  # The site's About is a window of the desk, closed, with the language
  # links of the address on screen.
  defp assert_about(document, path) do
    about = Floki.find(document, ~s([data-testid="site-window-about"]))
    assert about != [], "#{path} missing the About window"
    assert Floki.attribute(about, "data-window-initial-open") == ["false"]
    assert Floki.text(about) =~ "Languages", "#{path} missing language links"

    localized = if path == "/", do: "/pt-BR", else: "/pt-BR" <> path

    assert Floki.find(about, ~s(a[hreflang="pt-BR"][href="#{localized}"])) != [],
           "#{path} missing its own localized link"
  end

  # The sign-in window is one of the desktop's own windows: a page reaches it
  # by patching to /connect, so the chat behind it never reloads. A plain link
  # to it would throw the reader's desktop away to draw the same thing again.
  describe "the way into the app" do
    test "the home's Welcome leads to an account", %{conn: conn} do
      document = conn |> get("/") |> html_response(200) |> Floki.parse_document!()

      sign_up = Floki.find(document, ~s([data-testid="welcome-sign-up"]))
      assert Floki.attribute(sign_up, "data-phx-link") == ["patch"]
      assert [href] = Floki.attribute(sign_up, "href")
      assert href =~ ~r{^/connect\?}
    end

    test "/connect still receives a session that ended", %{conn: conn} do
      body = conn |> get("/connect?reason=expired") |> html_response(200)

      assert body =~ ~s(data-testid="session-alert")
      assert body =~ ~s(id="nickname")
    end
  end

  describe "public locale negotiation" do
    test "redirects first visits to the browser's localized public URL", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "pt-BR,pt;q=0.9,en;q=0.8")
        |> get("/features")

      assert redirected_to(conn) == "/pt-BR/features"
      assert get_session(conn, :locale) == "pt_BR"
    end

    test "redirects unprefixed public pages to an existing non-default preference", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{locale: "pt_BR"})
        |> put_req_header("accept-language", "en-US,en;q=0.9")
        |> get("/features")

      assert redirected_to(conn) == "/pt-BR/features"
      assert get_session(conn, :locale) == "pt_BR"
    end

    test "localized public pages save the locale preference", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/pt-BR/features")

      assert html_response(conn, 200) =~ ~s(lang="pt-BR")
      assert get_session(conn, :locale) == "pt_BR"
    end

    test "does not redirect sitemap requests by browser locale", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "pt-BR,pt;q=0.9,en;q=0.8")
        |> get("/sitemap.xml")

      assert response(conn, 200) =~ "<sitemapindex"
    end

    test "does not redirect sitemap chunk requests by browser locale", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "pt-BR,pt;q=0.9,en;q=0.8")
        |> get("/sitemaps/public-1.xml")

      assert response(conn, 200) =~ "<urlset"
    end
  end

  describe "a page's windows" do
    # A page's windows sit on one desktop with the chat's, the site's About and
    # the one-window pages; two windows sharing a DOM id would be one window
    # to the window manager.
    test "every window of a page has a DOM id no other window on the desktop has" do
      others =
        MapSet.new(
          [Document.window_id(About.window()) | Registry.window_ids()] ++
            Enum.map(WindowRegistry.windows(), & &1.id)
        )

      for page <- PublicPages.all() ++ PublicPages.guides() do
        ids = for window <- page_windows(page.path), do: Document.window_id(window)

        assert ids == Enum.uniq(ids), "#{page.path} declares a window twice"

        for id <- ids do
          refute id in others, "#{page.path}'s #{id} is the id of another window on the desktop"
        end
      end
    end

    test "a visitor's home is the chat, with the home's windows closed behind it", %{conn: conn} do
      document = conn |> get("/") |> html_response(200) |> Floki.parse_document!()

      assert [group] = Floki.find(document, ~s([data-testid="site-windows"]))
      assert Floki.attribute(group, "data-window-group-open") == ["false"]
      assert Floki.attribute(group, "data-window-group-focus") == ["false"]

      # Closed is not absent: the home's words are in its HTML.
      assert Floki.text(group) =~ "Your community isn’t yours."

      # The chat is what the home shows, so a reader's starts at once
      # (`lib/site/boot_policy.js`; a crawler's still waits).
      assert Floki.attribute(document, "html", "data-boot") == ["reader"]
    end

    test "every other page opens on arrival, in front", %{conn: conn} do
      document = conn |> get("/features") |> html_response(200) |> Floki.parse_document!()

      assert [group] = Floki.find(document, ~s([data-testid="site-windows"]))
      assert Floki.attribute(group, "data-window-group-open") == ["true"]
      assert Floki.attribute(group, "data-window-group-focus") == ["true"]
    end

    test "a visitor's desk has an icon per page of the site", %{conn: conn} do
      document = conn |> get("/faq") |> html_response(200) |> Floki.parse_document!()

      for page <- PublicPages.all() do
        icon = Floki.find(document, ~s([data-testid="desktop-icon-page-#{page.page}"]))

        assert Floki.attribute(icon, "data-window-shortcut-action") == ["open_page"]
        assert Floki.attribute(icon, "data-window-shortcut") == [Atom.to_string(page.page)]
      end

      assert Floki.find(document, ~s([data-testid="desktop-icon-site-about"])) != []
    end
  end

  describe "GET /" do
    test "contains SEO meta tags", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)
      document = Floki.parse_document!(body)

      assert body =~ "Retro Hex Chat"
      assert body =~ ~s(name="description")
      assert body =~ ~s(property="og:title")
      assert body =~ ~s(property="og:description")
      assert body =~ ~s(property="og:url" content="https://retrohexchat.app/")

      assert body =~
               ~s(property="og:image" content="https://retrohexchat.app/images/social/retrohexchat_og.png")

      assert body =~ ~s(property="og:image:width" content="1200")
      assert body =~ ~s(property="og:image:height" content="630")
      assert body =~ ~s(name="twitter:card")
      assert body =~ ~s(rel="canonical" href="https://retrohexchat.app/")

      assert body =~
               ~s(rel="alternate" hreflang="pt-BR" href="https://retrohexchat.app/pt-BR")

      assert body =~ ~s(rel="alternate" hreflang="x-default" href="https://retrohexchat.app/")

      # The home page is where the application is described, and it is described
      # exactly once: emitting `SoftwareApplication` on all ninety-eight landing
      # URLs claimed one entity ninety-eight times with the same `url`.
      types =
        document
        |> Floki.find(~s(script[type="application/ld+json"]))
        |> Enum.map(fn {"script", _attrs, [body]} ->
          body |> String.trim() |> Jason.decode!() |> Map.fetch!("@type")
        end)

      assert types == ["WebSite", "Organization", "SoftwareApplication"]
    end

    test "uses English lang attribute", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)
      assert body =~ ~s(lang="en")
    end

    # A page is read before the chat starts: its first response carries the
    # page whole and the chat only as an empty window saying it is opening —
    # no message, no folder, no dialog — so a search engine indexes the page
    # and nothing a conversation said.
    test "carries the page and only the frame of the chat", %{conn: conn} do
      document = conn |> get("/") |> html_response(200) |> Floki.parse_document!()

      assert [loading] = Floki.find(document, ~s([data-testid="chat-boot-loading"]))
      assert Floki.attribute(loading, "data-nosnippet") != []
      assert Floki.find(document, ~s([phx-update="stream"])) == []
      assert Floki.find(document, ~s([data-window-id^="desktop-launcher-"])) == []
      assert Floki.find(document, ~s([data-testid="kick-dialog"])) == []
    end
  end

  describe "sub-page SEO" do
    # On the head each page is built with; each page's test above proves the
    # page it serves carries that head.
    test "landing page titles and descriptions are unique and concise" do
      pages =
        for {path, _heading_id} <- @landing_pages do
          %{title: title, description: description} = page_head(path)

          assert title != "", "#{path} has an empty title"
          assert String.length(escaped(title)) <= 70, "#{path} title is too long: #{title}"
          assert description != nil, "#{path} is missing meta description"
          assert String.length(description) <= 170, "#{path} description is too long"

          {path, title, description}
        end

      assert pages |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == length(pages)
      assert pages |> Enum.map(&elem(&1, 2)) |> Enum.uniq() |> length() == length(pages)
    end

    # The questions and the structured data come from one list in `Site.Pages.Faq`,
    # so a rich result can never quote an answer the page stopped giving.
    test "FAQ page states its questions as FAQPage structured data", %{conn: conn} do
      conn = get(conn, "/faq")
      document = conn |> html_response(200) |> Floki.parse_document!()

      faq =
        document
        |> Floki.find(~s(script[type="application/ld+json"]))
        |> Enum.map(&(&1 |> elem(2) |> hd() |> String.trim() |> Jason.decode!()))
        |> Enum.find(&(&1["@type"] == "FAQPage"))

      assert faq, "/faq emits no FAQPage structured data"
      assert faq["url"] == "https://retrohexchat.app/faq"

      questions = Enum.map(faq["mainEntity"], & &1["name"])
      answers = Enum.map(faq["mainEntity"], &get_in(&1, ["acceptedAnswer", "text"]))

      assert length(questions) == length(Faq.entries())
      assert "Is it free?" in questions
      refute Enum.any?(answers, &(&1 in [nil, ""]))

      # Every question the page draws is a question the structured data states.
      for question <- questions do
        assert html_response(get(build_conn(), "/faq"), 200) =~ question
      end
    end

    test "localized public paths canonicalize to their clean locale path", %{conn: conn} do
      conn = get(conn, "/pt-BR/features")
      body = html_response(conn, 200)

      assert body =~ ~s(lang="pt-BR")
      assert body =~ ~s(rel="canonical" href="https://retrohexchat.app/pt-BR/features")

      assert body =~
               ~s(property="og:url" content="https://retrohexchat.app/pt-BR/features")
    end

    test "query locale is not a public canonical URL shape", %{conn: conn} do
      conn = get(conn, "/features?locale=pt_BR")
      body = html_response(conn, 200)

      assert body =~ ~s(lang="en")
      assert body =~ ~s(rel="canonical" href="https://retrohexchat.app/features")
      refute body =~ "features?locale=pt_BR"
    end
  end

  describe "shared layout" do
    test "a localized page links the public pages in its own language", %{conn: conn} do
      # The app, the showcase and the archive have one address in every
      # language; the language menu names English on purpose, with hreflang.
      single_address = ~r{^/(chat|showcase|archive)(/|$)}

      for {path, _} <- @landing_pages do
        localized = if path == "/", do: "/pt-BR", else: "/pt-BR" <> path
        document = conn |> get(localized) |> html_response(200) |> Floki.parse_document!()

        english =
          document
          |> Floki.find(~s{a[href^="/"]:not([hreflang])})
          |> Floki.attribute("href")
          |> Enum.reject(&(String.starts_with?(&1, "/pt-BR") or &1 =~ single_address))

        assert english == [], "#{localized} links English pages: #{inspect(Enum.uniq(english))}"
      end
    end
  end

  describe "crawl controls" do
    test "app pages are not indexable", %{conn: conn} do
      conn = get(conn, "/connect")
      body = html_response(conn, 200)

      assert body =~ ~s(name="robots" content="noindex, nofollow, noarchive")
    end

    test "robots.txt exposes the sitemap and blocks technical areas", %{conn: conn} do
      conn = get(conn, "/robots.txt")
      body = response(conn, 200)

      assert body =~ "Sitemap: https://retrohexchat.app/sitemap.xml"
      assert body =~ "Allow: /chat/help"
      assert body =~ "Disallow: /p2p/"
    end

    # Reachable at its URL is the whole job, and the trap is `phx.digest`: it
    # rewrites a top-level file to `llms-<digest>.txt`, whose first path segment
    # is not the one `static_paths/0` names, so the prefix has to be in
    # `static_only_matching/0` too or this 404s in production and nowhere else.
    test "llms.txt is served and maps the public pages", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      assert body =~ "# Retro Hex Chat"
      assert body =~ "https://retrohexchat.app/chat/help"
      assert body =~ "https://retrohexchat.app/faq"
      assert body =~ "https://retrohexchat.app/mirc-commands"
    end

    # The showcase is submitted in the sitemap, linked from the home page footer
    # and serves `index, follow`. Blocking it here made all three of those a lie
    # and earned one "submitted URL blocked by robots.txt" per component page.
    test "robots.txt does not block the showcase it submits", %{conn: conn} do
      conn = get(conn, "/robots.txt")
      body = response(conn, 200)

      refute body =~ "Disallow: /showcase"
    end

    test "sitemap index points to chunked public sitemaps", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      body = response(conn, 200)

      assert String.starts_with?(body, ~s(<?xml version="1.0" encoding="UTF-8"?>))
      assert body =~ ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
      assert body =~ "<loc>https://retrohexchat.app/sitemaps/public-1.xml</loc>"
      assert [etag] = get_resp_header(conn, "etag")
      assert String.starts_with?(etag, ~s(W/"))
      assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
      refute body =~ "<urlset"
      refute body =~ ~s(xmlns:xhtml="http://www.w3.org/1999/xhtml")
      refute body =~ "?locale="
    end

    # `public, max-age=3600` promises a shared cache may store these, and no
    # shared cache stores a response that sets a cookie. Nothing sets one today
    # — the controller never asks for a CSRF token, so the session stays
    # untouched even when a pipeline fetches it — and this is what keeps it that
    # way, because the promise is in the header where a CDN will read it.
    test "sitemaps carry no cookie, so a shared cache can honour their lifetime" do
      for path <- ["/sitemap.xml", "/sitemaps/public-1.xml"] do
        conn = get(build_conn(), path)

        assert response(conn, 200)
        assert get_resp_header(conn, "set-cookie") == [], "#{path} sets a cookie"
      end
    end

    test "sitemap index supports conditional requests", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      [etag] = get_resp_header(conn, "etag")

      conn =
        conn
        |> recycle()
        |> put_req_header("if-none-match", etag)
        |> get("/sitemap.xml")

      assert response(conn, 304) == ""
      assert get_resp_header(conn, "etag") == [etag]
    end

    test "sitemap chunks contain public URLs only", %{conn: conn} do
      conn = get(conn, "/sitemaps/public-1.xml")
      body = response(conn, 200)

      assert String.starts_with?(body, ~s(<?xml version="1.0" encoding="UTF-8"?>))
      assert body =~ ~s(xmlns:xhtml="http://www.w3.org/1999/xhtml")
      assert body =~ "<loc>https://retrohexchat.app/</loc>"
      assert body =~ "<loc>https://retrohexchat.app/pt-BR</loc>"
      assert body =~ "<loc>https://retrohexchat.app/features</loc>"
      assert body =~ "<loc>https://retrohexchat.app/pt-BR/features</loc>"

      assert body =~
               ~s(<xhtml:link rel="alternate" hreflang="pt-BR" href="https://retrohexchat.app/pt-BR/features" />)

      assert body =~
               ~s(<xhtml:link rel="alternate" hreflang="x-default" href="https://retrohexchat.app/features" />)

      refute body =~ "<loc>https://retrohexchat.app/about</loc>"
      refute body =~ "?locale="

      # `changefreq` and `priority` are ignored by every search engine that
      # reads this file. `lastmod` is not, which is why it has to be true: it
      # comes from the day the page's own source last changed in git, and a
      # page whose day is unknowable gets none rather than a guess.
      refute body =~ "<changefreq>"
      refute body =~ "<priority>"
      assert body =~ ~r|<lastmod>\d{4}-\d{2}-\d{2}</lastmod>|

      dates = Regex.scan(~r|<lastmod>([^<]+)</lastmod>|, body, capture: :all_but_first)

      assert length(Enum.uniq(dates)) > 1,
             "every page claims the same lastmod, which is the stamp-the-deploy-date mistake"

      {_conn, help_body} =
        sitemap_chunk_body_containing(conn, "<loc>https://retrohexchat.app/chat/help</loc>")

      assert help_body =~ "<loc>https://retrohexchat.app/chat/help</loc>"
      refute_sitemap_chunks_contain(conn, "<loc>https://retrohexchat.app/chat/help/welcome</loc>")
    end

    test "sitemap chunks support gzip responses", %{conn: conn} do
      {conn, body} =
        sitemap_chunk_body_containing(conn, "<loc>https://retrohexchat.app/chat/help</loc>",
          gzip: true
        )

      assert get_resp_header(conn, "content-encoding") == ["gzip"]
      assert get_resp_header(conn, "vary") == ["accept-encoding"]
      assert body =~ "<urlset"
      assert body =~ "<loc>https://retrohexchat.app/chat/help</loc>"
    end

    test "unknown sitemap chunks return 404", %{conn: conn} do
      conn = get(conn, "/sitemaps/missing.xml")

      assert response(conn, 404) == "Not found"
    end
  end

  defp page_windows(path), do: path |> load_page() |> Map.fetch!(:windows)

  defp page_head(path), do: path |> load_page() |> Head.from_page()

  defp escaped(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp load_page(path) do
    {page, params} =
      case path do
        "/games/" <> slug -> {RetroHexChatWeb.Site.Pages.Game, %{"slug" => slug}}
        path -> {page_at(path), %{}}
      end

    {:ok, loaded} = page.load(params, %{locale: "en", visitor?: true})
    loaded
  end

  defp page_at(path) do
    %{page: key} =
      Enum.find(
        PublicPages.all() ++ PublicPages.guides(),
        &(&1.path == path)
      )

    Registry.page(key)
  end

  defp sitemap_chunk_body_containing(conn, snippet, opts \\ []) do
    result =
      conn
      |> sitemap_chunk_paths()
      |> Enum.find_value(fn path ->
        chunk_conn =
          conn
          |> recycle()
          |> maybe_accept_gzip(opts)
          |> get(path)

        body = sitemap_chunk_body(chunk_conn, opts)

        if body =~ snippet do
          {chunk_conn, body}
        end
      end)

    result || flunk("expected one sitemap chunk to contain #{inspect(snippet)}")
  end

  defp refute_sitemap_chunks_contain(conn, snippet) do
    conn
    |> sitemap_chunk_paths()
    |> Enum.each(fn path ->
      chunk_conn = conn |> recycle() |> get(path)

      refute response(chunk_conn, 200) =~ snippet
    end)
  end

  defp sitemap_chunk_paths(conn) do
    conn = conn |> recycle() |> get("/sitemap.xml")
    body = response(conn, 200)

    paths =
      ~r|<loc>https://retrohexchat\.app(?<path>/sitemaps/public-\d+\.xml)</loc>|
      |> Regex.scan(body, capture: :all_but_first)
      |> List.flatten()

    assert paths != []

    paths
  end

  defp maybe_accept_gzip(conn, opts) do
    if Keyword.get(opts, :gzip, false) do
      put_req_header(conn, "accept-encoding", "gzip")
    else
      conn
    end
  end

  defp sitemap_chunk_body(conn, opts) do
    if Keyword.get(opts, :gzip, false) do
      conn |> response(200) |> :zlib.gunzip()
    else
      response(conn, 200)
    end
  end
end
