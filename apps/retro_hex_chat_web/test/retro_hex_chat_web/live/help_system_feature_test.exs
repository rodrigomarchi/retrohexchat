defmodule RetroHexChatWeb.HelpSystemFeatureTest do
  @moduledoc """
  End-to-end tests for the dedicated help page at /chat/help.
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview_feature

  describe "Help Page E2E" do
    test "help page renders with all categories", %{conn: conn} do
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

    test "topic deep-link shows content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/cmd-join")

      assert html =~ "/join"
      assert html =~ "Enter a chat channel"
    end

    test "cross-reference links use topic URLs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/welcome")

      assert html =~ "Welcome to RetroHexChat"
    end

    test "defaults to welcome topic when no topic specified", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help")

      assert html =~ "Welcome to RetroHexChat"
      assert html =~ "Quick Start"
    end

    test "breadcrumbs shown for selected topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/cmd-join")

      assert html =~ "Breadcrumb"
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

      assert html =~ "Help Topics"
      assert html =~ "help_topics"
    end
  end
end
