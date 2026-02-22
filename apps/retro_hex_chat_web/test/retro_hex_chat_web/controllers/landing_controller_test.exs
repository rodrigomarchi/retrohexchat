defmodule RetroHexChatWeb.LandingControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  @landing_pages [
    {"/", "hero"},
    {"/about", "problem"},
    {"/how-it-works", "how-it-works"},
    {"/features", "features"},
    {"/privacy", "privacy"},
    {"/install", "install"},
    {"/community", "open-source"},
    {"/faq", "faq"}
  ]

  describe "all landing pages" do
    for {path, section_id} <- @landing_pages do
      test "GET #{path} returns 200", %{conn: conn} do
        conn = get(conn, unquote(path))
        assert html_response(conn, 200)
      end

      test "GET #{path} contains section id=#{section_id}", %{conn: conn} do
        conn = get(conn, unquote(path))
        body = html_response(conn, 200)
        assert body =~ ~s(id="#{unquote(section_id)}")
      end

      test "GET #{path} loads landing-specific assets", %{conn: conn} do
        conn = get(conn, unquote(path))
        body = html_response(conn, 200)
        assert body =~ "/assets/css/landing.css"
        assert body =~ "/assets/js/landing.js"
        refute body =~ "/assets/js/app.js"
        refute body =~ "/assets/css/app.css"
      end

      test "GET #{path} does not contain LiveView references", %{conn: conn} do
        conn = get(conn, unquote(path))
        body = html_response(conn, 200)
        refute body =~ "phx-track-static"
        refute body =~ "data-phx-session"
        refute body =~ "LiveSocket"
      end
    end
  end

  describe "GET /" do
    test "contains SEO meta tags", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)

      assert body =~ "Retro Hex Chat"
      assert body =~ ~s(name="description")
      assert body =~ ~s(property="og:title")
      assert body =~ ~s(property="og:description")
      assert body =~ ~s(name="twitter:card")
      assert body =~ ~s(application/ld+json)
    end

    test "uses English lang attribute", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)
      assert body =~ ~s(lang="en")
    end
  end

  describe "sub-page SEO" do
    test "GET /about has unique page title", %{conn: conn} do
      conn = get(conn, "/about")
      body = html_response(conn, 200)
      assert body =~ "About Retro Hex Chat"
      assert body =~ ~s(rel="canonical")
      assert body =~ "/about"
    end

    test "GET /how-it-works has unique page title", %{conn: conn} do
      conn = get(conn, "/how-it-works")
      body = html_response(conn, 200)
      assert body =~ "How Retro Hex Chat Works"
    end

    test "GET /features has unique page title", %{conn: conn} do
      conn = get(conn, "/features")
      body = html_response(conn, 200)
      assert body =~ "Features"
    end

    test "GET /privacy has unique page title", %{conn: conn} do
      conn = get(conn, "/privacy")
      body = html_response(conn, 200)
      assert body =~ "Privacy Comparison"
    end

    test "GET /install has unique page title", %{conn: conn} do
      conn = get(conn, "/install")
      body = html_response(conn, 200)
      assert body =~ "Install Retro Hex Chat"
    end

    test "GET /community has unique page title", %{conn: conn} do
      conn = get(conn, "/community")
      body = html_response(conn, 200)
      assert body =~ "Open Source"
    end

    test "GET /faq has unique page title", %{conn: conn} do
      conn = get(conn, "/faq")
      body = html_response(conn, 200)
      assert body =~ "FAQ"
    end
  end

  describe "shared layout" do
    test "all pages include header and footer", %{conn: conn} do
      for {path, _} <- @landing_pages do
        conn = get(conn, path)
        body = html_response(conn, 200)
        assert body =~ "landing-header", "#{path} missing header"
        assert body =~ "landing-footer", "#{path} missing footer"
      end
    end
  end
end
