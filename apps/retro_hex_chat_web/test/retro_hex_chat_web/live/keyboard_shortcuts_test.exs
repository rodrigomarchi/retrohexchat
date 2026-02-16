defmodule RetroHexChatWeb.Live.KeyboardShortcutsTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  describe "cheatsheet dialog" do
    test "Ctrl+Shift+/ opens cheatsheet", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatO"), "/chat")

      html =
        render_click(view, "window_keydown", %{
          "key" => "/",
          "ctrlKey" => true,
          "shiftKey" => true,
          "altKey" => false
        })

      assert html =~ "cheatsheet-dialog"
      assert html =~ "Keyboard Shortcuts"
    end

    test "Escape closes cheatsheet", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatE"), "/chat")

      render_click(view, "window_keydown", %{
        "key" => "/",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      })

      html = render_click(view, "window_keydown", %{"key" => "Escape"})
      refute html =~ "cheatsheet-dialog"
    end

    test "Ctrl+Shift+/ toggles cheatsheet off", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatT"), "/chat")

      params = %{
        "key" => "/",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      }

      render_click(view, "window_keydown", params)
      html = render_click(view, "window_keydown", params)
      refute html =~ "cheatsheet-dialog"
    end

    test "cheatsheet renders categories", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatC"), "/chat")

      html =
        render_click(view, "window_keydown", %{
          "key" => "/",
          "ctrlKey" => true,
          "shiftKey" => true,
          "altKey" => false
        })

      assert html =~ "Navigation"
      assert html =~ "System"
    end

    test "close_dialog event closes cheatsheet", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatX"), "/chat")

      render_click(view, "window_keydown", %{
        "key" => "/",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      })

      html = render_click(view, "close_dialog", %{"dialog" => "cheatsheet"})
      refute html =~ "cheatsheet-dialog"
    end
  end

  describe "shortcut_action event dispatch" do
    test "toggle_search opens search", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SASearch"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "toggle_search"})
      assert html =~ "search-bar"
    end

    test "toggle_options_dialog opens options", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SAOpts"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "toggle_options_dialog"})
      assert html =~ "options-dialog"
    end

    test "toggle_cheatsheet opens cheatsheet", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SACheat"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "toggle_cheatsheet"})
      assert html =~ "cheatsheet-dialog"
    end

    test "unknown action is no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SAUnkn"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "nonexistent_action"})
      assert html =~ "chat-input-form"
    end

    test "open_help opens help dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SAHelp"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "open_help"})
      assert html =~ "help-dialog"
    end
  end
end
