defmodule RetroHexChatWeb.ChatDesktopShellTest do
  @moduledoc """
  The chat page renders as a Win98 desktop: the whole chat layout lives in one
  pinned window over a taskbar with a tray clock.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  describe "desktop shell" do
    test "static render shows a boot loading state until LiveView connects", %{conn: conn} do
      html =
        conn
        |> chat_conn("Desk#{uid()}")
        |> get("/chat")
        |> html_response(200)

      assert html =~ ~s(data-testid="chat-boot-loading")
      assert html =~ "Opening chat..."
    end

    test "renders the chat inside a persistent desktop", %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(view, ~s(#chat-desktop[data-persist-key="chat"][data-persist="true"]))

      # The desk carries no chrome of its own: the menus hang under the chat
      # window's own title bar, where Win98 put an application's menus, and
      # there is no header strip above the workspace to hold them.
      refute html =~ ~s(data-testid="app-header")
      refute html =~ ~s(data-testid="status-bar-app")

      assert has_element?(view, ~s([data-window-id="chat"] [data-window-menu] #menubar))
      assert has_element?(view, ~s(#menubar [data-testid="language-menu-item-pt_BR"]))

      assert has_element?(
               view,
               ~s(#menubar [data-testid="language-menu-item-pt_BR"] a[href^="/locale/pt_BR"])
             )
    end

    test "pins game launchers as desktop shortcuts", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(
               view,
               ~s(#chat-desktop [data-testid="desktop-shortcut-retro-games"][data-window-shortcut="retro-games"][data-window-shortcut-action="open_retro_games"])
             )

      assert has_element?(
               view,
               ~s(#chat-desktop [data-testid="desktop-shortcut-arcade"][data-window-shortcut="arcade-games"][data-window-shortcut-action="open_arcade"])
             )
    end

    test "the chat window is pinned and opens windowed, not maximized", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(
               view,
               ~s(#chat-desktop [data-window-id="chat"][data-window-pinned="true"][data-window-default-maximized="false"])
             )

      # Windowed only means something if it opens somewhere sensible: centered,
      # and sized off the workspace rather than in fixed pixels, with the
      # registry's geometry as the floor it never opens below. Without the
      # geometry reaching the DOM the manager falls back to its own 360px
      # default and the chat opens as a sliver.
      assert has_element?(
               view,
               ~s([data-window-id="chat"][data-window-default-centered="true"][data-window-default-fill="0.86"])
             )

      assert has_element?(
               view,
               ~s([data-window-id="chat"][data-window-default-width="920"][data-window-default-height="580"])
             )

      # Maximize is how you get the old behaviour back, so the control has to
      # be there.
      assert has_element?(view, ~s([data-window-id="chat"] [data-window-control="maximize"]))

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

      assert has_element?(
               view,
               ~s([data-window-id="chat"] [data-testid="tab-bar"][role="tablist"])
             )

      refute has_element?(
               view,
               ~s([data-testid="tab-bar"] [data-testid="conversation-toolbar-actions"])
             )

      assert has_element?(
               view,
               ~s([data-testid="conversation-toolbar"] [data-testid="conversation-toolbar-actions"])
             )

      # The sidebar toggles ship in the toolbar but belong to the stacked layout:
      # a desk reaches its sidebars through the rails, so the cluster is hidden
      # from md up.
      assert has_element?(
               view,
               ~s([data-testid="conversation-toolbar-sidebar-toggles"][class*="md:hidden"] [data-testid="conversation-toolbar-conversations"])
             )

      assert has_element?(
               view,
               ~s([data-testid="conversation-toolbar-sidebar-toggles"][class*="md:hidden"] [data-testid="conversation-toolbar-nicklist"])
             )

      assert has_element?(
               view,
               ~s([data-testid="conversation-toolbar"] [data-testid="channel-view-switcher"])
             )

      refute has_element?(
               view,
               ~s([data-testid="topic-bar"] [data-testid="channel-view-switcher"])
             )

      assert has_element?(view, ~s([data-window-id="chat"] #conversations-mount.h-full))
      assert has_element?(view, ~s([data-window-id="chat"] #conversations.h-full))

      assert has_element?(
               view,
               ~s([data-window-id="chat"] [data-testid="conversations-collapse-toggle"])
             )

      refute has_element?(view, ~s([data-window-id="chat"] [data-testid="conversations-rail"]))

      assert has_element?(
               view,
               ~s([data-window-id="chat"] [data-testid="nicklist-collapse-toggle"])
             )

      refute has_element?(view, ~s([data-window-id="chat"] [data-testid="nicklist-rail"]))
      # The composer spans the whole conversation: it follows the messages /
      # nicklist row instead of sharing a column with it, so the nicklist ends
      # above the input rather than beside it.
      assert has_element?(
               view,
               ~s([data-testid="channel-content-row"] ~ #composer-region #chat-input-area)
             )

      refute has_element?(view, ~s([data-testid="channel-main-column"] #chat-input-area))
      assert has_element?(view, ~s([data-testid="channel-content-row"] [data-testid="nicklist"]))

      assert has_element?(
               view,
               ~s([data-testid="chat-input-form"] [data-testid="format-btn-bold"])
             )

      assert has_element?(view, ~s([data-testid="chat-input-form"] [data-testid="char-counter"]))
    end

    test "the tab bar closes the chat area from below, after the content row", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      # Sibling combinators pin the order, not just the presence: the tab strip
      # follows the messages/nicklist row instead of leading the top chrome.
      assert has_element?(
               view,
               ~s([data-testid="channel-content-row"] ~ [data-testid="tab-bar"])
             )

      refute has_element?(
               view,
               ~s([data-testid="tab-bar"] ~ [data-testid="conversation-toolbar"])
             )

      refute has_element?(
               view,
               ~s([data-testid="tab-bar"] ~ [data-testid="channel-content-row"])
             )
    end

    test "viewport events collapse mobile panels and restore the prior desktop state", %{
      conn: conn
    } do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

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

    test "a channel can switch from Chat to Space without replacing the composer", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      chat_button =
        ~s([data-testid="conversation-toolbar"] [data-testid="channel-view-switcher"] button[phx-value-view="chat"])

      space_button =
        ~s([data-testid="conversation-toolbar"] [data-testid="channel-view-switcher"] button[phx-value-view="space"])

      assert has_element?(view, "#{chat_button} svg")
      assert has_element?(view, ~s(#{chat_button}[aria-label="Chat"][title="Chat"]))
      refute has_element?(view, chat_button, "Chat")
      assert has_element?(view, "#{space_button} svg")
      assert has_element?(view, ~s(#{space_button}[aria-label="Space"][title="Space"]))
      refute has_element?(view, space_button, "Space")

      view
      |> element(space_button)
      |> render_click()

      # Entering the space shows the character picker first; the canvas only
      # mounts after a character is chosen.
      assert has_element?(view, ~s([data-testid="space-character-select"]))
      refute has_element?(view, ~s([data-testid="channel-space-shell"]))

      view
      |> element(~s([data-testid="space-avatar-knight"]))
      |> render_click()

      assert has_element?(
               view,
               ~s([data-testid="channel-content-row"] [data-testid="channel-space-shell"][phx-hook="SpaceCanvasHook"][data-space-mode="channel"][data-avatar="knight"])
             )

      assert has_element?(
               view,
               ~s([data-testid="channel-space-shell"] [data-testid="space-loading"]),
               "Channel Space"
             )

      assert has_element?(
               view,
               ~s([data-testid="channel-space-shell"] [data-testid="space-loading"]),
               "Entering channel space..."
             )

      assert has_element?(view, ~s([data-testid="channel-content-row"] [data-testid="nicklist"]))

      assert has_element?(
               view,
               ~s([data-testid="channel-content-row"] ~ #composer-region #chat-input-area)
             )
    end

    test "a private conversation can switch from Chat to Space with its loading panel", %{
      conn: conn
    } do
      other = "Peer#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      render_click(view, "nicklist_dblclick", %{"nick" => other})

      view
      |> element(
        ~s([data-testid="conversation-toolbar"] [data-testid="channel-view-switcher"] button[phx-value-view="space"])
      )
      |> render_click()

      # Pick a character to dismiss the picker and mount the private-room canvas.
      assert has_element?(view, ~s([data-testid="space-character-select"]))

      view
      |> element(~s([data-testid="space-avatar-sorceress"]))
      |> render_click()

      assert has_element?(
               view,
               ~s([data-testid="channel-content-row"] [data-testid="channel-space-shell"][phx-hook="SpaceCanvasHook"][data-space-mode="direct_message"])
             )

      assert has_element?(
               view,
               ~s([data-testid="channel-space-shell"] [data-testid="space-loading"]),
               "Private Space"
             )

      assert has_element?(
               view,
               ~s([data-testid="channel-space-shell"] [data-testid="space-loading"]),
               "Opening private room..."
             )
    end
  end

  describe "start menu" do
    test "start button and menu render with Tools/View/Help items", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      assert has_element?(view, ~s(#chat-desktop [data-window-start]))
      assert has_element?(view, ~s(#chat-start-menu[data-window-start-menu]))
      # Migrated dialogs open client-side; unmigrated ones still dispatch
      # toolbar_action events.
      assert has_element?(view, ~s(#chat-start-menu [data-window-open="address-book"]))
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="toggle_channel_list"]))
      assert has_element?(view, ~s(#chat-start-menu [phx-value-action="help_topics"]))
    end

    test "a start menu item opens its dialog through toolbar_action", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Desk#{uid()}"), "/chat")

      # Channel List keeps the server opener (it loads the /list rows on open).
      view
      |> element(~s(#chat-start-menu [phx-value-action="toggle_channel_list"]))
      |> render_click()

      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})
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
