defmodule RetroHexChatWeb.ChatDesktopShellTest do
  @moduledoc """
  The chat page renders as a Win98 desktop: the whole chat layout lives in one
  pinned, maximized-by-default window over a taskbar with a tray clock.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  describe "desktop shell" do
    test "renders the chat inside a persistent desktop", %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(view, ~s(#chat-desktop[data-persist-key="chat"][data-persist="true"]))
      # Header chrome (menu bar + status bar) lives in the desktop header slot,
      # above the workspace.
      assert html =~ ~s(data-testid="status-bar-app")
    end

    test "the chat window is pinned and maximized by default", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(
               view,
               ~s(#chat-desktop [data-window-id="chat"][data-window-pinned="true"][data-window-default-maximized="true"])
             )

      # Pinned: no close control in the window title bar.
      refute has_element?(view, ~s([data-window-id="chat"] [data-window-control="close"]))
      assert has_element?(view, ~s([data-window-id="chat"] [data-window-control="minimize"]))
    end

    test "the taskbar has a chat window button and a tray clock", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(view, ~s(#chat-desktop [data-window-taskbar="chat"]))
      assert has_element?(view, ~s(#chat-tray-clock[phx-hook="ClockHook"]))
      # The tray owns the clock — the header status bar no longer shows one.
      refute has_element?(view, "#clock-display")
    end

    test "the chat layout (tabs, composer, nicklist) lives inside the window body", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(view, ~s([data-window-id="chat"] [role="tablist"]))
      assert has_element?(view, ~s([data-window-id="chat"] #chat-input-area))
    end
  end

  describe "start menu" do
    test "start button and menu render with Tools/View/Help items", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(view, ~s(#chat-desktop [data-window-start]))
      assert has_element?(view, ~s(#chat-start-menu[data-window-start-menu]))
      # Items dispatch the existing toolbar_action events (no window wiring yet).
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="toggle_address_book"]))
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="toggle_channel_list"]))
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="help_topics"]))
    end

    test "a start menu item opens its dialog through toolbar_action", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      refute has_element?(view, "#alias-dialog-show-trigger")

      view
      |> element(~s(#chat-start-menu [phx-value-action="open_alias_dialog"]))
      |> render_click()

      assert has_element?(view, "#alias-dialog-show-trigger")
    end

    test "the admin group is permission-gated", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      refute has_element?(view, ~s(#chat-start-menu [phx-value-action="open_admin_console"]))
      refute has_element?(view, ~s(#chat-start-menu [phx-value-action="open_bot_dialog"]))
    end

    test "admins see the admin group", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")

      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="open_admin_console"]))
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="open_bot_dialog"]))
    end
  end

  describe "managed-window plumbing" do
    test "window_open/window_closed for unknown or non-managed ids are no-ops", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      render_hook(view, "window_open", %{"id" => "not-a-window"})
      render_hook(view, "window_closed", %{"id" => "not-a-window"})

      assert MapSet.size(:sys.get_state(view.pid).socket.assigns.open_windows) == 0
    end
  end
end
