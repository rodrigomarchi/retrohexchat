defmodule RetroHexChatWeb.HelpSystemE2ETest do
  @moduledoc """
  End-to-end tests for the CHM-style Help System.
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "Help Dialog" do
    test "1.1 menu opens help dialog", %{conn: conn} do
      view = connect_user(conn, "E2EHelp#{uid()}")
      refute render(view) =~ "help-dialog"

      html = render_click(view, "toggle_help_dialog")

      assert html =~ "help-dialog"
      assert html =~ "RetroHexChat Help"
    end

    test "1.2 Help > Help Topics menu opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EMenu#{uid()}")
      html = render_click(view, "toggle_help_dialog")
      assert html =~ "help-dialog"
    end

    test "1.3 Contents tree shows all categories", %{conn: conn} do
      view = connect_user(conn, "E2ECat#{uid()}")
      html = render_click(view, "toggle_help_dialog")

      assert html =~ "Getting Started"
      assert html =~ "Commands"
      assert html =~ "Services"
      assert html =~ "Channel Modes"
      assert html =~ "Text Formatting"
      assert html =~ "Features"
      assert html =~ "User Interface"
      assert html =~ "Keyboard Shortcuts"
    end

    test "1.4 Click topic shows content in right pane", %{conn: conn} do
      view = connect_user(conn, "E2ETopic#{uid()}")
      render_click(view, "toggle_help_dialog")

      html = render_click(view, "help_select_topic", %{"id" => "cmd-join"})
      assert html =~ "/join"
      assert html =~ "Join a channel"
    end

    test "1.5 Switch to Index tab and filter keywords", %{conn: conn} do
      view = connect_user(conn, "E2EIdx#{uid()}")
      render_click(view, "toggle_help_dialog")

      html = render_click(view, "help_tab", %{"tab" => "index"})
      assert html =~ "help-index-filter"

      html = render_keyup(view, "help_index_filter", %{"value" => "buddy"})
      assert html =~ "buddy"
    end

    test "1.6 Click keyword shows topic", %{conn: conn} do
      view = connect_user(conn, "E2EKw#{uid()}")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "index"})

      html = render_click(view, "help_select_topic", %{"id" => "feature-notify-list"})
      assert html =~ "Notify List"
    end

    test "1.7 Switch to Search tab and search", %{conn: conn} do
      view = connect_user(conn, "E2ESrch#{uid()}")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "search"})

      html = render_click(view, "help_search", %{"query" => "format"})
      assert html =~ "help-result-formatting-overview"
    end

    test "1.8 Click search result shows topic", %{conn: conn} do
      view = connect_user(conn, "E2ERes#{uid()}")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "search"})
      render_click(view, "help_search", %{"query" => "format"})

      html = render_click(view, "help_select_topic", %{"id" => "formatting-overview"})
      assert html =~ "Text Formatting Overview"
    end

    test "1.9 Close dialog with X button", %{conn: conn} do
      view = connect_user(conn, "E2ECls#{uid()}")
      render_click(view, "toggle_help_dialog")
      assert render(view) =~ "help-dialog"

      html = render_click(view, "close_help")
      refute html =~ "help-dialog"
    end

    test "1.10 Cross-reference navigation via content click", %{conn: conn} do
      view = connect_user(conn, "E2EXref#{uid()}")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_select_topic", %{"id" => "welcome"})

      html = render_click(view, "help_content_click", %{"data-help-topic" => "connecting"})
      assert html =~ "Connecting"
    end

    test "1.11 Empty state shown initially", %{conn: conn} do
      view = connect_user(conn, "E2EEmpty#{uid()}")
      html = render_click(view, "toggle_help_dialog")
      assert html =~ "Select a topic from the navigation pane"
    end

    test "1.12 Search with Enter key", %{conn: conn} do
      view = connect_user(conn, "E2EEnter#{uid()}")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "search"})

      html = render_keyup(view, "help_search_input", %{"key" => "Enter", "value" => "kick"})
      assert html =~ "help-result-cmd-kick"
    end

    test "1.13 Menu bar has Help Topics item", %{conn: conn} do
      view = connect_user(conn, "E2EMBar#{uid()}")
      html = render(view)
      assert html =~ "menu-help-topics"
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid, do: rem(System.unique_integer([:positive]), 100_000)
end
