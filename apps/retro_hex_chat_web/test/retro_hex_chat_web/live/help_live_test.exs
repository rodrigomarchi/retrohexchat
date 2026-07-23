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

    test "renders language menu links that preserve the current topic", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat/help/commands-overview")

      assert has_element?(view, ~s(#help-menubar [data-testid="language-menu-item-pt_BR"]))

      assert has_element?(
               view,
               ~s(#help-menubar [data-testid="language-menu-item-pt_BR"] a[href="/pt-BR/chat/help/commands-overview"])
             )
    end

    test "renders keyboard shortcuts topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/keyboard-shortcuts")

      assert html =~ "Keyboard Shortcuts"
      assert html =~ "Ctrl+Shift"
    end

    test "redirects nonexistent topics to the canonical help root", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/chat/help"}}} =
               live(conn, "/chat/help/nonexistent-topic-xyz")
    end

    test "redirects explicit welcome topic to the canonical help root", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/chat/help"}}} = live(conn, "/chat/help/welcome")
    end

    test "redirects localized explicit welcome topic to the localized help root", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/pt-BR/chat/help"}}} =
               live(conn, "/pt-BR/chat/help/welcome")
    end

    test "help root is the canonical URL for the welcome topic", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "Welcome to RetroHexChat"
      assert html =~ "Quick Start"
      assert html =~ ~s(<link rel="canonical" href="https://retrohexchat.app/chat/help")
      assert html =~ ~s(<meta property="og:url" content="https://retrohexchat.app/chat/help")
      refute html =~ "https://retrohexchat.app/chat/help/welcome"
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
      refute html =~ "/assets/js/app.js"
    end

    test "localized help paths have clean self-referencing canonicals", %{conn: conn} do
      conn = get(conn, "/pt-BR/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ ~s(lang="pt-BR")

      assert html =~
               ~s(<link rel="canonical" href="https://retrohexchat.app/pt-BR/chat/help/commands-overview")

      assert html =~
               ~s(<meta property="og:url" content="https://retrohexchat.app/pt-BR/chat/help/commands-overview")

      assert html =~
               ~s(rel="alternate" hreflang="x-default" href="https://retrohexchat.app/chat/help/commands-overview")

      refute html =~ "?locale="
    end

    test "topic structured data includes topic breadcrumb", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      document = conn |> html_response(200) |> Floki.parse_document!()

      [{"script", _attrs, [json_ld_body]}] =
        Floki.find(document, ~s(script[type="application/ld+json"]))

      json_ld = json_ld_body |> String.trim() |> Jason.decode!()

      assert json_ld["@type"] == "BreadcrumbList"

      assert List.last(json_ld["itemListElement"]) == %{
               "@type" => "ListItem",
               "position" => 3,
               "name" => "IRC Commands Reference",
               "item" => "https://retrohexchat.app/chat/help/commands-overview"
             }
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

  describe "windowed help desktop (CHM viewer)" do
    test "renders the desktop shell, window and CHM chrome", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat/help")

      assert has_element?(view, "[data-testid=help-desktop]")
      assert has_element?(view, "[data-testid=help-window]")
      assert has_element?(view, "[data-testid=help-content-pane]")
      assert has_element?(view, "[data-testid=help-menu-bar]")
      assert has_element?(view, "[data-testid=help-status-bar]")
      assert has_element?(view, "[data-testid=help-search-input]")
    end

    test "search filters topics and links to them", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat/help")

      view
      |> form(~s(form[phx-change="help_search"]), %{q: "keyboard"})
      |> render_change()

      assert has_element?(
               view,
               ~s([data-testid=help-search-results] a[href="/chat/help/keyboard-shortcuts"])
             )
    end

    test "an empty search shows a no-results hint", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat/help")

      view
      |> form(~s(form[phx-change="help_search"]), %{q: "zzz-no-such-topic-xyz"})
      |> render_change()

      assert has_element?(view, "[data-testid=help-search-empty]")
    end

    test "switching to the Index tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat/help")

      view |> element("[data-testid=help-tab-index]") |> render_click()

      assert has_element?(view, ~s([data-testid=help-tab-index][aria-selected="true"]))
    end
  end
end
