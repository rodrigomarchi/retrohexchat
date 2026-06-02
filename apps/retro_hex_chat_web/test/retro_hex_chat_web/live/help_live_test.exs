defmodule RetroHexChatWeb.HelpLiveTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview

  describe "GET /chat/help (static render)" do
    test "renders help page with all categories", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help")

      assert html =~ "Help Topics"
      assert html =~ "Getting Started"
      assert html =~ "Chat &amp; Messaging"
      assert html =~ "Users &amp; Identity"
      assert html =~ "Channels"
      assert html =~ "Channel Modes"
      assert html =~ "Moderation"
      assert html =~ "Bots"
      assert html =~ "Automation"
      assert html =~ "Text Formatting"
      assert html =~ "User Interface"
      assert html =~ "P2P Games: Action"
      assert html =~ "Solo Arcade: FPS"
      assert html =~ "Solo Arcade: Adventures"
    end

    test "defaults to welcome topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help")

      assert html =~ "Welcome to RetroHexChat"
      assert html =~ "Quick Start"
    end

    test "has tree-view navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help")

      assert html =~ "tree-view"
    end
  end

  describe "GET /chat/help/:topic" do
    test "renders specific topic content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/commands-overview")

      assert html =~ "IRC Commands Reference"
      assert html =~ "/join"
      assert html =~ "/quit"
    end

    test "renders keyboard shortcuts topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/keyboard-shortcuts")

      assert html =~ "Keyboard Shortcuts"
      assert html =~ "Ctrl+Shift"
    end

    test "handles nonexistent topic by falling back to welcome", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/nonexistent-topic-xyz")

      assert html =~ "Welcome to RetroHexChat"
      assert html =~ "Quick Start"
    end

    test "shows breadcrumbs for selected topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/cmd-join")

      assert html =~ "Breadcrumb"
      assert html =~ "Commands"
    end

    test "includes SEO meta tags in static render", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ ~s(<meta name="description")
      assert html =~ ~s(<meta property="og:title")
      assert html =~ ~s(<link rel="canonical")
    end

    test "static render includes exactly one h1", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      document = html_response(conn, 200) |> Floki.parse_document!()
      h1s = Floki.find(document, "h1")

      assert length(h1s) == 1
      assert h1s |> Floki.text() |> String.trim() == "IRC Commands Reference"
    end

    test "uses the help-only LiveView JavaScript bundle", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ "/assets/js/help_live.js"
      refute html =~ "/assets/js/retrohex_content.js"
      refute html =~ "/assets/js/v2_app.js"
    end

    test "localized help paths have clean self-referencing canonicals", %{conn: conn} do
      conn = get(conn, "/pt-BR/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ ~s(lang="pt-BR")

      assert html =~
               ~s(<link rel="canonical" href="https://retrohexchat.com/pt-BR/chat/help/commands-overview")

      assert html =~
               ~s(<meta property="og:url" content="https://retrohexchat.com/pt-BR/chat/help/commands-overview")

      assert html =~
               ~s(rel="alternate" hreflang="x-default" href="https://retrohexchat.com/chat/help/commands-overview")

      refute html =~ "?locale="
    end

    test "shows content header with icon and title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/cmd-join")

      assert html =~ "/join"
      assert html =~ "Enter a chat channel"
    end
  end

  describe "cross-reference links" do
    test "help_link renders with proper topic URLs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/cmd-ban")

      assert html =~ ~s(href="/chat/help/cmd-kick")
    end
  end

  describe "SEO" do
    test "page has h1 tag with topic title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/commands-overview")

      assert html =~ "<h1"
      assert html =~ "IRC Commands Reference"
    end
  end
end
