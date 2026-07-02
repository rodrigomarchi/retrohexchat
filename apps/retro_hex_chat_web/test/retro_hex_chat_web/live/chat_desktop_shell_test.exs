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
end
