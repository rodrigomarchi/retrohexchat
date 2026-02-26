defmodule RetroHexChatWeb.Components.ToolbarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Toolbar

  @default_assigns [
    connected: true,
    dnd_enabled: false,
    notification_count: 0,
    is_admin: false
  ]

  defp render_toolbar(overrides \\ []) do
    assigns = Keyword.merge(@default_assigns, overrides)
    render_component(&Toolbar.toolbar/1, assigns)
  end

  describe "connection group (solo, no dropdown)" do
    test "shows Disconnect when connected" do
      html = render_toolbar(connected: true)
      assert html =~ ~s(data-testid="toolbar-disconnect")
      refute html =~ ~s(data-testid="toolbar-connect")
    end

    test "shows Connect when not connected" do
      html = render_toolbar(connected: false)
      assert html =~ ~s(data-testid="toolbar-connect")
      refute html =~ ~s(data-testid="toolbar-disconnect")
    end
  end

  describe "group structure" do
    test "renders toolbar-group wrapper for options" do
      html = render_toolbar()
      assert html =~ ~s(class="toolbar-group")
    end

    test "renders only the options group toggle" do
      html = render_toolbar()
      assert html =~ ~s(data-toolbar-group="options")
      refute html =~ ~s(data-toolbar-group="view")
      refute html =~ ~s(data-toolbar-group="tools")
      refute html =~ ~s(data-toolbar-group="notifications")
      refute html =~ ~s(data-toolbar-group="help")
    end

    test "renders toolbar-group-dropdown container" do
      html = render_toolbar()
      assert html =~ ~s(class="toolbar-group-dropdown u-hidden")
    end

    test "renders options group toggle test id" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-group-options")
      refute html =~ ~s(data-testid="toolbar-group-view")
      refute html =~ ~s(data-testid="toolbar-group-tools")
      refute html =~ ~s(data-testid="toolbar-group-notifications")
      refute html =~ ~s(data-testid="toolbar-group-help")
    end

    test "renders dropdown separators" do
      html = render_toolbar()
      assert html =~ ~s(class="toolbar-dropdown-separator")
    end
  end

  describe "options group — view items" do
    test "renders Channel List button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-channel-list")
      assert html =~ ~s(phx-click="channel_list")
    end

    test "renders Toggle Conversations button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-toggle-conversations")
      assert html =~ ~s(phx-click="toggle_conversations")
    end

    test "renders Toggle Nicklist button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-toggle-nicklist")
      assert html =~ ~s(phx-click="toggle_nicklist")
    end

    test "renders Find button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-find")
      assert html =~ ~s(phx-click="open_search")
    end

    test "dropdown items have labels" do
      html = render_toolbar()
      assert html =~ ~s(class="toolbar-group-label">Channel List</span>)
      assert html =~ ~s(class="toolbar-group-label">Find</span>)
    end
  end

  describe "options group — tool items" do
    @tools_buttons [
      {"toolbar-address-book", "toggle_address_book"},
      {"toolbar-highlight", "open_highlight_dialog"},
      {"toolbar-ignore-list", "open_ignore_dialog"},
      {"toolbar-url-catcher", "toggle_url_catcher"},
      {"toolbar-channel-central", "open_channel_central"},
      {"toolbar-perform", "open_perform_dialog"},
      {"toolbar-sounds", "open_sound_settings_dialog"},
      {"toolbar-ctcp-settings", "open_ctcp_settings_dialog"},
      {"toolbar-flood-protection", "open_flood_protection_dialog"},
      {"toolbar-alias-editor", "open_alias_dialog"},
      {"toolbar-custom-menus", "open_custom_menus_dialog"},
      {"toolbar-autorespond", "open_autorespond_dialog"},
      {"toolbar-settings", "settings"}
    ]

    for {testid, event} <- @tools_buttons do
      test "renders #{testid} button with #{event} event" do
        html = render_toolbar()
        assert html =~ ~s(data-testid="#{unquote(testid)}")
        assert html =~ ~s(phx-click="#{unquote(event)}")
      end
    end
  end

  describe "options group — notification items" do
    test "renders DND button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-dnd")
      assert html =~ ~s(phx-click="toggle_dnd")
    end

    test "DND button has active class when enabled" do
      html = render_toolbar(dnd_enabled: true)
      assert html =~ "toolbar-btn--active"
    end

    test "DND button has no active class when disabled" do
      html = render_toolbar(dnd_enabled: false)
      refute html =~ "toolbar-btn--active"
    end

    test "renders Bell button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-bell")
      assert html =~ ~s(phx-click="toggle_notification_center")
    end

    test "shows notification badge when count > 0" do
      html = render_toolbar(notification_count: 5)
      assert html =~ ~s(data-testid="notification-badge")
      assert html =~ "5"
    end

    test "hides notification badge when count is 0" do
      html = render_toolbar(notification_count: 0)
      refute html =~ ~s(data-testid="notification-badge")
    end

    test "caps notification badge at 99+" do
      html = render_toolbar(notification_count: 150)
      assert html =~ "99+"
    end
  end

  describe "help button (solo, no dropdown)" do
    test "renders Help Topics link" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-help")
      assert html =~ ~s(href="/chat/help")
      assert html =~ ~s(target="_blank")
    end

    test "does not render Keyboard Shortcuts button" do
      html = render_toolbar()
      refute html =~ ~s(data-testid="toolbar-cheatsheet")
      refute html =~ ~s(phx-click="toggle_cheatsheet")
    end
  end
end
