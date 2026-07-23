defmodule RetroHexChatWeb.LandingLiveTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @landing_pages [
    {"/", "hero-heading"},
    {"/how-it-works", "how-it-works-heading"},
    {"/features", "features-heading"},
    {"/privacy", "privacy-heading"},
    {"/install", "install-heading"},
    {"/community", "community-heading"},
    {"/faq", "faq-heading"}
  ]

  @secondary_landing_pages @landing_pages -- [{"/", "hero-heading"}]

  describe "all landing pages" do
    for {path, heading_id} <- @landing_pages do
      test "GET #{path} renders successfully", %{conn: conn} do
        {:ok, _view, html} = live(conn, unquote(path))
        assert html =~ ~s(id="#{unquote(heading_id)}")
      end

      test "GET #{path} uses retrohex.css", %{conn: conn} do
        conn = get(conn, unquote(path))
        body = html_response(conn, 200)
        assert body =~ "retrohex.css"
        refute body =~ "landing.css"
      end

      test "GET #{path} uses the lightweight public JavaScript bundle", %{conn: conn} do
        conn = get(conn, unquote(path))
        body = html_response(conn, 200)

        assert body =~ "/assets/js/public_pages.js"
        refute body =~ "/assets/js/retrohex_content.js"
        refute body =~ "/assets/js/app.js"
      end

      test "GET #{path} renders exactly one page-level h1", %{conn: conn} do
        conn = get(conn, unquote(path))
        document = html_response(conn, 200) |> Floki.parse_document!()
        h1s = Floki.find(document, "h1")

        assert length(h1s) == 1
        assert Floki.attribute(h1s, "id") == [unquote(heading_id)]

        h1_classes = h1s |> Floki.attribute("class") |> Enum.join(" ")
        refute h1_classes =~ "sr-only"
      end
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

  describe "static win98 taskbar" do
    for {path, _heading_id} <- @landing_pages do
      test "GET #{path} renders the taskbar, start menu and page links", %{conn: conn} do
        conn = get(conn, unquote(path))
        document = html_response(conn, 200) |> Floki.parse_document!()

        assert Floki.find(document, ".desktop-taskbar") != []

        # Start menu is toggled by the existing vanilla data-toggle-target JS.
        assert Floki.find(document, ~s([data-toggle-target="#landing-start-menu"])) != []

        start_menu = Floki.find(document, "#landing-start-menu")
        assert start_menu != []
        hrefs = start_menu |> Floki.find("a") |> Floki.attribute("href")
        assert "/connect" in hrefs
        assert "/faq" in hrefs
        assert "/chat/help" in hrefs

        # The current page's taskbar button is pressed (is-active).
        active = Floki.find(document, "a.desktop-taskbar__button.is-active")
        assert Floki.attribute(active, "href") == [unquote(path)]
      end
    end
  end

  describe "top menu bar and clock" do
    for {path, _heading_id} <- @landing_pages do
      test "GET #{path} renders a real dropdown menu bar and a tray clock", %{conn: conn} do
        conn = get(conn, unquote(path))
        document = html_response(conn, 200) |> Floki.parse_document!()

        assert Floki.find(document, ~s(nav[role="menubar"])) != []

        # At least the three landing menus (Navigate / Help / Language).
        triggers = Floki.find(document, "[data-menubar-trigger]")
        assert length(triggers) >= 3

        # Dropdowns start hidden (the vanilla public_pages.js toggles u-hidden).
        dropdowns = Floki.find(document, "[data-menubar-dropdown]")
        assert dropdowns != []

        Enum.each(dropdowns, fn dd ->
          classes = dd |> Floki.attribute("class") |> Enum.join(" ")
          assert classes =~ "u-hidden"
        end)

        # Menu items are real links: pages, docs and locale switchers.
        menubar_hrefs =
          document |> Floki.find(~s(nav[role="menubar"] a)) |> Floki.attribute("href")

        assert "/faq" in menubar_hrefs
        assert "/chat/help" in menubar_hrefs
        assert Enum.any?(menubar_hrefs, &String.starts_with?(&1, "/pt-BR"))

        # Tray clock element (updated client-side by public_pages.js).
        assert Floki.find(document, "[data-clock]") != []
      end
    end
  end

  describe "secondary landing page content" do
    for {path, heading_id} <- @secondary_landing_pages do
      test "GET #{path} starts with a visible intro summary", %{conn: conn} do
        conn = get(conn, unquote(path))
        document = html_response(conn, 200) |> Floki.parse_document!()

        intro =
          Floki.find(
            document,
            ~s(section[aria-labelledby="#{unquote(heading_id)}"] > div:first-child)
          )

        assert Floki.find(intro, "h1") != []
        assert intro |> Floki.find("p") |> Floki.text() |> String.trim() != ""
      end
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

      [{"script", _attrs, [json_ld_body]}] =
        Floki.find(document, ~s(script[type="application/ld+json"]))

      assert json_ld_body |> String.trim() |> Jason.decode!() |> Map.fetch!("@type") ==
               "SoftwareApplication"
    end

    test "uses English lang attribute", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)
      assert body =~ ~s(lang="en")
    end

    test "wordmark image includes intrinsic dimensions", %{conn: conn} do
      conn = get(conn, "/")
      document = html_response(conn, 200) |> Floki.parse_document!()
      wordmark = Floki.find(document, ~s(img[src="/images/landing/wordmark.svg"]))

      assert Floki.attribute(wordmark, "width") == ["800"]
      assert Floki.attribute(wordmark, "height") == ["120"]
    end

    test "renders rich chat, space, and conference visuals", %{conn: conn} do
      conn = get(conn, "/")
      document = html_response(conn, 200) |> Floki.parse_document!()

      section = Floki.find(document, ~s(section[aria-labelledby="conversation-modes-heading"]))

      assert section != []
      assert Floki.find(section, ~s([aria-label="Persistent chat workspace diagram"])) != []
      assert Floki.find(section, ~s([aria-label="Channel conference topology diagram"])) != []

      space_image =
        Floki.find(section, ~s(img[src="/images/landing/space_end_of_time_showcase.png"]))

      assert space_image != []

      assert Floki.attribute(space_image, "alt") == [
               "End of Time Space map with avatars and in-world chat bubbles"
             ]

      section_text = Floki.text(section)
      assert section_text =~ "Channels, DMs, bots, commands, replies"
      assert section_text =~ "Space renders that same conversation as a live map"
      assert section_text =~ "Conference keeps media inside the channel"
    end

    test "uses static data attributes for progressive interactions", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)

      assert body =~ ~s(data-toggle-target="#mobile-nav")
      assert body =~ ~s(data-show-target="#readme-popup")
      assert body =~ ~s(data-hide-target="#readme-popup")
      assert body =~ ~s(data-modal)
      refute body =~ "phx-click="
      refute body =~ "phx-click-away"
    end
  end

  describe "sub-page SEO" do
    for {path, _heading_id} <- @landing_pages do
      test "GET #{path} has a self-referencing canonical URL", %{conn: conn} do
        path = unquote(path)
        conn = get(conn, path)
        body = html_response(conn, 200)

        assert body =~ ~s(rel="canonical" href="https://retrohexchat.app#{path}")
      end
    end

    test "GET /how-it-works has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/how-it-works")
      assert html =~ "How Retro Hex Chat Works"
    end

    test "GET /features has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/features")
      assert html =~ "Features"
    end

    test "GET /features shows space and conference feature visuals", %{conn: conn} do
      conn = get(conn, "/features")
      document = html_response(conn, 200) |> Floki.parse_document!()

      assert Floki.find(
               document,
               ~s(img[src="/images/landing/space_end_of_time_showcase.png"])
             ) != []

      assert Floki.find(document, ~s([aria-label="Channel conference topology diagram"])) != []
    end

    test "GET /privacy has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/privacy")
      assert html =~ "Privacy Comparison"
    end

    test "GET /install has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/install")
      assert html =~ "Install Retro Hex Chat"
    end

    test "GET /community has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/community")
      assert html =~ "Open Source"
    end

    test "GET /faq has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/faq")
      assert html =~ "FAQ"
    end

    test "landing page titles and descriptions are unique and concise", %{conn: conn} do
      pages =
        for {path, _heading_id} <- @landing_pages do
          conn = get(conn, path)
          document = html_response(conn, 200) |> Floki.parse_document!()
          title = document |> Floki.find("title") |> Floki.text() |> String.trim()

          description =
            document
            |> Floki.find(~s(meta[name="description"]))
            |> Floki.attribute("content")
            |> List.first()

          assert title != "", "#{path} has an empty title"
          assert String.length(title) <= 70, "#{path} title is too long: #{title}"
          assert description != nil, "#{path} is missing meta description"
          assert String.length(description) <= 170, "#{path} description is too long"

          {path, title, description}
        end

      assert pages |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == length(pages)
      assert pages |> Enum.map(&elem(&1, 2)) |> Enum.uniq() |> length() == length(pages)
    end

    test "FAQ page does not emit FAQPage structured data", %{conn: conn} do
      conn = get(conn, "/faq")
      body = html_response(conn, 200)

      refute body =~ "FAQPage"
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
    test "all pages include header and footer", %{conn: conn} do
      for {path, _} <- @landing_pages do
        {:ok, _view, html} = live(conn, path)
        assert html =~ "app-header", "#{path} missing header"
        assert html =~ "About", "#{path} missing footer"
        assert html =~ "Languages", "#{path} missing language links"
        assert html =~ ~s(hreflang="pt-BR"), "#{path} missing localized footer links"
        assert html =~ ~s(href="/pt-BR), "#{path} missing clean localized footer links"
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
      assert body =~ "Disallow: /showcase"
      assert body =~ "Disallow: /p2p/"
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
      assert body =~ "<loc>https://retrohexchat.app/chat/help</loc>"
      refute body =~ "<loc>https://retrohexchat.app/chat/help/welcome</loc>"

      assert body =~
               ~s(<xhtml:link rel="alternate" hreflang="pt-BR" href="https://retrohexchat.app/pt-BR/features" />)

      assert body =~
               ~s(<xhtml:link rel="alternate" hreflang="x-default" href="https://retrohexchat.app/features" />)

      refute body =~ "<loc>https://retrohexchat.app/about</loc>"
      refute body =~ "?locale="
      refute body =~ "<lastmod>"
      refute body =~ "<changefreq>"
      refute body =~ "<priority>"
    end

    test "sitemap chunks support gzip responses", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-encoding", "gzip")
        |> get("/sitemaps/public-1.xml")

      body = conn |> response(200) |> :zlib.gunzip()

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
end
