defmodule RetroHexChatWeb.ChatDesktopShellTest do
  @moduledoc """
  The chat page renders as a Win98 desktop: the whole chat layout lives in one
  pinned window over a taskbar with a tray clock.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  import ExUnit.CaptureLog

  @moduletag :liveview

  describe "desktop shell" do
    test "pins app folders and opens games from the Games folder", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      assert has_element?(
               view,
               ~s(#chat-desktop [data-testid="desktop-icon-games"][data-window-shortcut="desktop-launcher-games"])
             )

      assert has_element?(
               view,
               ~s(#chat-desktop [data-testid="desktop-launcher-window-games"][data-window-id="desktop-launcher-games"][data-window-initial-open="false"])
             )

      # The folder is the catalogue: a game per game, each opening its home
      # over the chat.
      assert has_element?(
               view,
               ~s(#chat-desktop [data-testid="desktop-launcher-window-games"] [data-testid="desktop-launcher-item-game-hex_pong"][href="/games/hex-pong"][data-phx-link="patch"])
             )

      refute has_element?(
               view,
               ~s(#chat-desktop [data-testid="desktop-launcher-item-retro-games"])
             )
    end

    test "a private conversation gets the same user list, naming its participants", %{
      conn: conn
    } do
      viewer = "Desk#{uid()}"
      peer = "Peer#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, viewer), "/")

      render_click(view, "switch_pm", %{"nickname" => peer})

      assert has_element?(view, ~s([data-testid="channel-content-row"] [data-testid="nicklist"]))

      refute has_element?(
               view,
               ~s([data-testid="nicklist-sidebar-shell"][class*="hidden"])
             )

      # The roster is the conversation's own, not whatever the last channel left
      # behind: the two people in it, the one you are talking to first.
      assigns = :sys.get_state(view.pid).socket.assigns
      assert Enum.map(assigns.conversation_members, & &1.nickname) == [peer, viewer]
    end

    test "switching back to a channel restores the channel roster", %{conn: conn} do
      viewer = "Desk#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, viewer), "/")

      channel = :sys.get_state(view.pid).socket.assigns.session.active_channel

      assert Enum.any?(
               :sys.get_state(view.pid).socket.assigns.conversation_members,
               &(&1.nickname == viewer)
             )

      render_click(view, "switch_pm", %{"nickname" => "Peer#{uid()}"})
      assert length(:sys.get_state(view.pid).socket.assigns.conversation_members) == 2

      render_click(view, "switch_channel", %{"channel" => channel})
      members = :sys.get_state(view.pid).socket.assigns.conversation_members

      assert Enum.any?(members, &(&1.nickname == viewer))
      assert :sys.get_state(view.pid).socket.assigns.session.active_channel == channel
    end

    test "the status tab is not a conversation and keeps no user list", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      render_click(view, "switch_to_status", %{})

      assert has_element?(
               view,
               ~s([data-testid="nicklist-sidebar-shell"][class*="hidden"])
             )
    end

    test "viewport events collapse mobile panels and restore the prior desktop state", %{
      conn: conn
    } do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.show_conversations
      assert assigns.show_nicklist
      refute assigns.mobile_viewport

      render_hook(view, "viewport_info", %{"width" => 390, "mobile" => true})
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.mobile_viewport
      refute assigns.show_conversations
      refute assigns.show_nicklist

      render_click(view, "toggle_conversations", %{})
      assert :sys.get_state(view.pid).socket.assigns.show_conversations

      render_hook(view, "viewport_info", %{"width" => 390, "mobile" => true, "height" => 720})
      assert :sys.get_state(view.pid).socket.assigns.show_conversations

      render_click(view, "switch_pm", %{"nickname" => "MobilePeer#{uid()}"})
      assigns = :sys.get_state(view.pid).socket.assigns
      refute assigns.show_conversations
      refute assigns.show_nicklist

      render_hook(view, "viewport_info", %{"width" => 900, "mobile" => false})
      assigns = :sys.get_state(view.pid).socket.assigns
      refute assigns.mobile_viewport
      assert assigns.show_conversations
      assert assigns.show_nicklist
    end
  end

  describe "start menu" do
    test "a start menu item opens its dialog through toolbar_action", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      # Channel List keeps the server opener (it loads the /list rows on open).
      view
      |> element(~s(#chat-start-menu [phx-value-action="toggle_channel_list"]))
      |> render_click()

      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})
    end

    test "the admin group is permission-gated", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      refute has_element?(view, ~s(#chat-start-menu [phx-value-action="open_admin_console"]))
      refute has_element?(view, ~s(#chat-start-menu [phx-value-action="open_bot_dialog"]))
    end

    test "admins see the admin group", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/")

      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="open_admin_console"]))
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="open_bot_dialog"]))
    end
  end

  describe "managed-window plumbing" do
    test "window_open/window_closed for unknown or non-managed ids are no-ops", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      render_hook(view, "window_open", %{"id" => "not-a-window"})
      render_hook(view, "window_closed", %{"id" => "not-a-window"})

      assert MapSet.size(:sys.get_state(view.pid).socket.assigns.open_windows) == 0
    end
  end

  describe "messages nobody handles" do
    test "are reported, not swallowed", %{conn: conn} do
      previous = Logger.level()
      Logger.configure(level: :warning)
      on_exit(fn -> Logger.configure(level: previous) end)

      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/")

      log =
        capture_log(fn ->
          send(view.pid, {:no_such_message, :payload})
          _ = :sys.get_state(view.pid)
        end)

      assert log =~ "DesktopLive: unhandled message {:no_such_message, :payload}"
    end
  end
end
