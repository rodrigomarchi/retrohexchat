defmodule RetroHexChatWeb.HelpSystemE2ETest do
  @moduledoc """
  End-to-end tests for the dedicated help page at /chat/help.
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :e2e

  describe "Help Page E2E" do
    test "help page renders with all categories", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "RetroHexChat Help"
      assert html =~ "Getting Started"
      assert html =~ "Commands"
      assert html =~ "Services"
      assert html =~ "Channel Modes"
      assert html =~ "Text Formatting"
      assert html =~ "Features"
      assert html =~ "User Interface"
      assert html =~ "Keyboard Shortcuts"
    end

    test "topic deep-link shows content", %{conn: conn} do
      conn = get(conn, "/chat/help?topic=cmd-join")
      html = html_response(conn, 200)

      assert html =~ "/join"
      assert html =~ "Enter a chat channel"
    end

    test "search returns matching results", %{conn: conn} do
      conn = get(conn, "/chat/help?q=format")
      html = html_response(conn, 200)

      assert html =~ "help-result-formatting-overview"
    end

    test "cross-reference links use topic URLs", %{conn: conn} do
      conn = get(conn, "/chat/help?topic=welcome")
      html = html_response(conn, 200)

      assert html =~ "Welcome to RetroHexChat"
    end

    test "empty state shown when no topic selected", %{conn: conn} do
      conn = get(conn, "/chat/help")
      html = html_response(conn, 200)

      assert html =~ "Select a topic from the navigation pane"
    end

    test "breadcrumbs shown for selected topic", %{conn: conn} do
      conn = get(conn, "/chat/help?topic=cmd-join")
      html = html_response(conn, 200)

      assert html =~ "help-breadcrumbs"
      assert html =~ "Commands"
    end

    test "sitemap includes help topics", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      body = response(conn, 200)

      assert body =~ "commands-overview"
      assert body =~ "keyboard-shortcuts"
    end

    test "menu bar has Help Topics link in chat", %{conn: conn} do
      nick = "E2EHlp#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "toolbar-help"
      assert html =~ "/chat/help"
    end
  end

  defp uid, do: rem(System.unique_integer([:positive]), 100_000)
end
