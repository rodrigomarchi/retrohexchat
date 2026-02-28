defmodule RetroHexChatWeb.LandingLiveTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @landing_pages [
    {"/", "hero-heading"},
    {"/about", "problem-heading"},
    {"/how-it-works", "how-it-works-heading"},
    {"/features", "features-heading"},
    {"/privacy", "privacy-heading"},
    {"/install", "install-heading"},
    {"/community", "opensource-heading"},
    {"/faq", "faq-heading"}
  ]

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
      {:ok, _view, html} = live(conn, "/about")
      assert html =~ "About Retro Hex Chat"
    end

    test "GET /how-it-works has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/how-it-works")
      assert html =~ "How Retro Hex Chat Works"
    end

    test "GET /features has unique page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/features")
      assert html =~ "Features"
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
  end

  describe "shared layout" do
    test "all pages include header and footer", %{conn: conn} do
      for {path, _} <- @landing_pages do
        {:ok, _view, html} = live(conn, path)
        assert html =~ "app-header", "#{path} missing header"
        assert html =~ "About", "#{path} missing footer"
      end
    end
  end
end
