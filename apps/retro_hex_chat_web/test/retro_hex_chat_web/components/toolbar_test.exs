defmodule RetroHexChatWeb.Components.ToolbarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Toolbar

  @default_assigns [
    connected: true,
    dnd_enabled: false,
    notification_count: 0,
    favorites: [],
    joined_channels: [],
    show_favorites_dropdown: false
  ]

  defp render_toolbar(overrides \\ []) do
    assigns = Keyword.merge(@default_assigns, overrides)
    render_component(&Toolbar.toolbar/1, assigns)
  end

  describe "connection group" do
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

  describe "view group" do
    test "renders Channel List button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-channel-list")
      assert html =~ ~s(phx-click="channel_list")
    end

    test "renders Toggle Treebar button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-toggle-treebar")
      assert html =~ ~s(phx-click="toggle_treebar")
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
  end

  describe "favorites group" do
    test "renders Favorites button" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-favorites")
      assert html =~ ~s(phx-click="toggle_favorites_dropdown")
    end

    test "shows empty state when no favorites" do
      html = render_toolbar(show_favorites_dropdown: true, favorites: [])
      assert html =~ "No favorites"
    end

    test "shows favorite channels when present" do
      favs = [%{channel_name: "#test", description: "Test channel"}]
      html = render_toolbar(show_favorites_dropdown: true, favorites: favs)
      assert html =~ "#test"
      assert html =~ "Test channel"
    end

    test "shows checkmark for joined favorites" do
      favs = [%{channel_name: "#test", description: ""}]

      html =
        render_toolbar(show_favorites_dropdown: true, favorites: favs, joined_channels: ["#test"])

      assert html =~ "&#10003;"
    end

    test "shows Organize Favorites item" do
      html = render_toolbar(show_favorites_dropdown: true)
      assert html =~ "Organize Favorites..."
      assert html =~ ~s(data-testid="toolbar-organize-favorites")
    end

    test "dropdown is hidden when show_favorites_dropdown is false" do
      html = render_toolbar(show_favorites_dropdown: false)
      refute html =~ "toolbar-dropdown--open"
    end

    test "dropdown is visible when show_favorites_dropdown is true" do
      html = render_toolbar(show_favorites_dropdown: true)
      assert html =~ "toolbar-dropdown--open"
    end
  end

  describe "tools group" do
    @tools_buttons [
      {"toolbar-address-book", "toggle_address_book"},
      {"toolbar-highlight", "open_highlight_dialog"},
      {"toolbar-ignore-list", "open_ignore_dialog"},
      {"toolbar-url-catcher", "toggle_url_catcher"},
      {"toolbar-channel-central", "open_channel_central"},
      {"toolbar-log-viewer", "open_log_viewer"},
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

  describe "notifications group" do
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

  describe "help group" do
    test "renders Help Topics link" do
      html = render_toolbar()
      assert html =~ ~s(data-testid="toolbar-help")
      assert html =~ ~s(href="/chat/help")
      assert html =~ ~s(target="_blank")
    end
  end
end
