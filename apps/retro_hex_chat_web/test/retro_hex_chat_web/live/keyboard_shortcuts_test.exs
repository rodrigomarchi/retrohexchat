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

    test "the window manager owns Escape; a client close unmounts the island", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatE"), "/chat")

      render_click(view, "window_keydown", %{
        "key" => "/",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      })

      assert has_element?(view, ~s([data-window-id="cheatsheet"]))

      # Escape is handled client-side (WM); the hook reports the close back.
      render_hook(view, "window_closed", %{"id" => "cheatsheet"})
      refute has_element?(view, ~s([data-window-id="cheatsheet"]))
    end

    test "Ctrl+Shift+/ re-invocation focuses (never toggle-closes)", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatT"), "/chat")

      params = %{
        "key" => "/",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      }

      render_click(view, "window_keydown", params)
      render_click(view, "window_keydown", params)
      assert has_element?(view, ~s([data-window-id="cheatsheet"]))
      assert_push_event(view, "window_command", %{action: "open", id: "cheatsheet"})
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
      assert html =~ "P2P Call Window"
      assert html =~ "Ctrl+Shift+."
    end

    test "close_dialog event closes cheatsheet", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CheatX"), "/chat")

      render_click(view, "window_keydown", %{
        "key" => "/",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      })

      render_click(view, "close_dialog", %{"dialog" => "cheatsheet"})
      # close_dialog now delegates to the window manager client-side.
      assert_push_event(view, "window_command", %{action: "close", id: "cheatsheet"})
    end
  end

  describe "shortcut_action event dispatch" do
    test "toggle_search opens search", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SASearch"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "toggle_search"})
      assert html =~ "search-bar"
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

    test "open_help pushes open_url event", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SAHelp"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "open_help"})
      # open_help now uses push_event to open /chat/help in a new tab
      assert html =~ "chat-input-form"
    end
  end
end
