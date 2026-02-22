defmodule RetroHexChatWeb.HelpControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  describe "GET /chat/help" do
    test "renders help page", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "RetroHexChat Help"
      assert html =~ "help-page"
      assert html =~ "contents-pane"
    end

    test "includes all 8 categories in navigation", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "Getting Started"
      assert html =~ "Commands"
      assert html =~ "Services"
      assert html =~ "Channel Modes"
      assert html =~ "Text Formatting"
      assert html =~ "Features"
      assert html =~ "User Interface"
      assert html =~ "Keyboard Shortcuts"
    end

    test "defaults to welcome topic when no topic specified", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "Welcome to RetroHexChat"
      assert html =~ "Quick Start"
    end

    test "has 98.css classes present", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "help-page-window"
      assert html =~ "tree-view"
    end
  end

  describe "GET /chat/help/<id>" do
    test "renders specific topic content", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ "IRC Commands Reference"
      assert html =~ "/join"
      assert html =~ "/quit"
    end

    test "renders keyboard shortcuts topic", %{conn: conn} do
      conn = get(conn, "/chat/help/keyboard-shortcuts")
      html = html_response(conn, 200)

      assert html =~ "Keyboard Shortcuts"
      assert html =~ "Ctrl+Shift"
    end

    test "handles nonexistent topic by falling back to welcome", %{conn: conn} do
      conn = get(conn, "/chat/help/nonexistent-topic-xyz")
      html = html_response(conn, 200)

      assert html =~ "Welcome to RetroHexChat"
      assert html =~ "Quick Start"
    end

    test "shows breadcrumbs for selected topic", %{conn: conn} do
      conn = get(conn, "/chat/help/cmd-join")
      html = html_response(conn, 200)

      assert html =~ "help-breadcrumbs"
      assert html =~ "Commands"
    end

    test "includes SEO meta tags", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ ~s(<meta name="description")
      assert html =~ ~s(<meta property="og:title")
      assert html =~ ~s(<link rel="canonical")
    end

    test "shows content header with icon", %{conn: conn} do
      conn = get(conn, "/chat/help/cmd-join")
      html = html_response(conn, 200)

      assert html =~ "help-content-header"
      assert html =~ "help-icon"
    end
  end

  describe "cross-reference links" do
    test "help-topic-link class links are rendered with proper URLs", %{conn: conn} do
      conn = get(conn, "/chat/help/cmd-ban")
      html = html_response(conn, 200)

      assert html =~ ~s(href="/chat/help/cmd-kick")
      assert html =~ "help-topic-link"
    end
  end

  describe "GET /sitemap.xml" do
    test "returns valid XML sitemap", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      assert response_content_type(conn, :xml)
      body = response(conn, 200)

      assert body =~ "<?xml version"
      assert body =~ "<urlset"
      assert body =~ "https://retrohexchat.com/chat/help"
      assert body =~ "commands-overview"
      assert body =~ "keyboard-shortcuts"
      assert body =~ "<lastmod>"
    end
  end

  describe "SEO" do
    test "page has h1 tag", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ "<h1"
      assert html =~ "IRC Commands Reference"
    end
  end
end
