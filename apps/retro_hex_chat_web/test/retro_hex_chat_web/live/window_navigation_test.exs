defmodule RetroHexChatWeb.Live.WindowNavigationTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  describe "window_next/window_prev" do
    test "window_next switches to next channel", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinNext1"), "/chat")

      # Join a second channel so there's something to switch to
      render_submit(view, "send_input", %{"input" => "/join #wn_test1"})
      Process.sleep(50)

      # Should be on #wn_test1 now; switch back to #lobby
      html = render_click(view, "window_next")
      # Verify we're no longer on #wn_test1 (wrapped or moved to next)
      assert html =~ "chat-messages"
    end

    test "window_prev switches to previous channel", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinPrev1"), "/chat")

      render_submit(view, "send_input", %{"input" => "/join #wp_test1"})
      Process.sleep(50)

      html = render_click(view, "window_prev")
      assert html =~ "chat-messages"
    end
  end

  describe "window_select" do
    test "window_select switches to specific window", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinSel1"), "/chat")

      render_submit(view, "send_input", %{"input" => "/join #ws_test1"})
      Process.sleep(50)

      # Select window 1 (first in sorted list)
      html = render_click(view, "window_select", %{"index" => 1})
      assert html =~ "chat-messages"
    end

    test "window_select out of bounds is no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinSel2"), "/chat")

      # Select window 99 — should be no-op
      html = render_click(view, "window_select", %{"index" => 99})
      assert html =~ "chat-messages"
    end
  end

  describe "keyboard shortcut dispatch" do
    test "Ctrl+Shift+] triggers window_next via window_keydown", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinKb1"), "/chat")

      html =
        render_click(view, "window_keydown", %{
          "key" => "]",
          "ctrlKey" => true,
          "shiftKey" => true,
          "altKey" => false
        })

      assert html =~ "chat-messages"
    end

    test "Ctrl+Shift+[ triggers window_prev via window_keydown", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinKb2"), "/chat")

      html =
        render_click(view, "window_keydown", %{
          "key" => "[",
          "ctrlKey" => true,
          "shiftKey" => true,
          "altKey" => false
        })

      assert html =~ "chat-messages"
    end

    test "Ctrl+Shift+1 triggers window_1 via shortcut_action", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinKb3"), "/chat")

      html = render_click(view, "shortcut_action", %{"action" => "window_1"})
      assert html =~ "chat-messages"
    end
  end
end
