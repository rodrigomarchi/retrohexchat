defmodule RetroHexChatWeb.ChatLive.Components.ChatShellTest do
  @moduledoc """
  The chat window's own menu bar, and the one derivation the tray needs.

  This used to cover an application header — a strip across the top of the
  screen holding the menus and a status bar. That header is gone: the menus
  hang under the chat window's title bar where Win98 put them, and what the
  status bar reported is now either in the tray (lag, mute, buddies) or was
  already a taskbar button of its own (an active call, a P2P session).
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.ChatShell

  @moduletag :unit

  defp menu(session, overrides \\ %{}) do
    assigns = Map.merge(%{session: session}, overrides)
    render_component(&ChatShell.chat_shell_menu/1, assigns)
  end

  describe "the window's menu bar" do
    test "renders the menu bar and its hook, and nothing of a header" do
      html = menu(Session.new("alice"))

      assert html =~ ~s(id="menubar")
      assert html =~ ~s(phx-hook="MenuBarHook")
      assert html =~ ~s(app-menu-bar__desktop-menu)

      # The desk carries no chrome of its own any more.
      refute html =~ ~s(data-testid="app-header")
      refute html =~ ~s(data-testid="status-bar-app")
    end

    test "the mobile rail carries every menu, each opening its own section" do
      html = menu(Session.new("alice"))

      for section <- ~w(file edit view tools p2p language help) do
        assert html =~ ~s(data-testid="app-mobile-menu-rail-#{section}")
        assert html =~ ~s(data-mobile-menu-open="#{section}")
        assert html =~ ~s(data-testid="app-mobile-menu-category-#{section}")
        assert html =~ ~s(data-testid="app-mobile-menu-section-#{section}")
      end
    end

    test "the menu names neither the user nor the conversation — the title bar does" do
      session = %{Session.new("alice") | active_channel: "#lobby", active_pm: "bob"}
      html = menu(session)

      refute html =~ "alice"
      refute html =~ "bob"
      refute html =~ "#lobby"
    end

    test "a peer session opens the P2P menu, and a relay opens privacy mode" do
      idle = menu(Session.new("alice"))
      assert idle =~ ~s(data-testid="context-menu-item-p2p_how_to_start")

      live =
        menu(Session.new("alice"), %{
          p2p_session: %{state: :connected, peer_nick: "trinity", turn_configured: true}
        })

      assert live =~ ~s(data-testid="context-menu-item-p2p_start_audio")
      assert live =~ ~s(data-testid="context-menu-item-p2p_toggle_privacy")
    end

    test "launching another program is not this window's menu's job" do
      # The arcade and the retro games open windows of their own that have
      # nothing to do with this conversation, so they are reached from the
      # Start menu. Same for the admin and runtime windows, which used to hang
      # off File and made it a thirty-row menu.
      html = menu(Session.new("alice"))

      refute html =~ ~s(data-testid="app-menu-games")
      refute html =~ "open_arcade"
      refute html =~ "open_retro_games"
      refute html =~ ~s(data-testid="app-menu-admin-submenu")
      refute html =~ ~s(data-testid="app-menu-system-submenu")
      refute html =~ "open_system_metrics"
    end

    test "the account window is reachable, not only its parts" do
      html = menu(Session.new("alice"))

      assert html =~ ~s(data-testid="context-menu-item-open_account_dialog")
    end

    test "View carries the display options, including stripping formatting" do
      html = menu(Session.new("alice"))

      assert html =~ ~s(data-testid="context-menu-item-toggle_strip_formatting")
    end
  end

  describe "online_buddy_count/1" do
    test "counts only the buddies who are online" do
      notify = %{entries: [%{online: true}, %{online: false}, %{online: true}]}

      assert ChatShell.online_buddy_count(notify) == 2
    end

    test "is zero for an empty or missing notify list" do
      assert ChatShell.online_buddy_count(%{entries: []}) == 0
      assert ChatShell.online_buddy_count(nil) == 0
    end
  end
end
