defmodule RetroHexChatWeb.UrlCatcherWindowTest do
  @moduledoc """
  Window contract for the URL Catcher: an always-mounted desktop window
  (client-owned visibility) whose openers push a `window_command`.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  describe "URL Catcher window" do
    test "renders as an always-mounted, initially closed desktop window", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UrlW#{uid()}"), "/chat")

      assert has_element?(
               view,
               ~s(#chat-desktop [data-window-id="url-catcher"][data-window-open="false"])
             )

      # Content island is mounted even while the window is closed.
      assert has_element?(view, ~s([data-window-id="url-catcher"] [data-testid="url-catcher"]))
      assert has_element?(view, ~s(#chat-desktop [data-window-taskbar="url-catcher"]))
    end

    test "the menu action opens/focuses the window via window_command", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UrlW#{uid()}"), "/chat")

      render_click(view, "toolbar_action", %{"action" => "toggle_url_catcher"})

      assert_push_event(view, "window_command", %{action: "open", id: "url-catcher"})
    end

    test "the start menu opens it client-side (no server round trip)", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UrlW#{uid()}"), "/chat")

      assert has_element?(view, ~s(#chat-start-menu [data-window-open="url-catcher"]))
    end

    test "URLs accumulate in the host while the window is closed", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UrlW#{uid()}"), "/chat")

      render_click(view, "ctx_chat_save_url", %{
        "url" => "https://example.com/hello",
        "author" => "Bob"
      })

      entries = :sys.get_state(view.pid).socket.assigns.url_catcher_entries
      assert Enum.any?(entries, &(&1.url == "https://example.com/hello"))
      # And the always-mounted island renders the captured URL.
      assert render(view) =~ "https://example.com/hello"
    end

    test "Escape is no longer a server-side dismissal for the URL Catcher", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UrlW#{uid()}"), "/chat")

      # The parent no longer tracks url-catcher visibility at all.
      refute Map.has_key?(:sys.get_state(view.pid).socket.assigns, :show_url_catcher)
      # And a stray Escape reaching the server does not crash.
      render_click(view, "window_keydown", %{"key" => "Escape"})
    end
  end
end
