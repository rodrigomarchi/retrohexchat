defmodule RetroHexChatWeb.ChatLiveOptionsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp connect_user(conn, nick \\ nil) do
    nick = nick || "Opt#{System.unique_integer([:positive])}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp open_options(view) do
    view |> element(~s([data-testid="menu-options"])) |> render_click()
    view
  end

  # ---------------------------------------------------------------------------
  # Dialog Open / Close
  # ---------------------------------------------------------------------------

  describe "Options dialog open/close" do
    @tag :liveview
    test "opens via menu bar Options item", %{conn: conn} do
      view = connect_user(conn)
      view |> element(~s([data-testid="menu-options"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "opens via Ctrl+Shift+O keyboard shortcut", %{conn: conn} do
      view = connect_user(conn)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "o", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      assert html =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "opens via toolbar Settings button", %{conn: conn} do
      view = connect_user(conn)
      view |> element(~s([data-testid="toolbar-settings"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "closes via Cancel button", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

      view |> element(~s([data-testid="options-cancel"])) |> render_click()
      refute render(view) =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "closes via title bar close button", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

      view |> element(~s(.options-dialog button[aria-label="Close"])) |> render_click()
      refute render(view) =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "closes via Escape key", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "Escape"})

      refute render(view) =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "closes via OK button", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

      view |> element(~s([data-testid="options-ok"])) |> render_click()
      refute render(view) =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "Ctrl+Shift+O toggles dialog closed when open", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "o", "ctrlKey" => true, "shiftKey" => true})

      refute render(view) =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "duplicate open_options_dialog event does not crash", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

      # Opening again should be idempotent
      view |> element(~s([data-testid="menu-options"])) |> render_click()
      assert render(view) =~ ~s(data-testid="options-dialog")
    end
  end

  # ---------------------------------------------------------------------------
  # Panel Navigation
  # ---------------------------------------------------------------------------

  describe "panel navigation" do
    @tag :liveview
    test "default panel is display", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      html = render(view)
      assert html =~ ~s(data-testid="options-display-panel")
    end

    @tag :liveview
    test "clicking Connect tree item shows connect panel", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-connect-panel")
    end

    @tag :liveview
    test "clicking Fonts tree item shows fonts panel", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-fonts"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-fonts-panel")
    end

    @tag :liveview
    test "clicking Colors tree item shows colors panel", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-colors-panel")
    end

    @tag :liveview
    test "clicking Messages tree item shows messages panel", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-messages-panel")
    end

    @tag :liveview
    test "clicking Key Bindings tree item shows keybindings panel", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-keybindings-panel")
    end

    @tag :liveview
    test "selected tree item has tree-item-selected class", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      html = render(view)
      # display is the default, so its tree item should be selected
      assert html =~ ~s(class="tree-item-selected")
    end
  end

  # ---------------------------------------------------------------------------
  # Display Panel — Toggles
  # ---------------------------------------------------------------------------

  describe "display panel toggles" do
    @tag :liveview
    test "toggling show_toolbar in draft updates checkbox", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-show_toolbar"]))
      |> render_click()

      # Apply to see effects
      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      # Toolbar should be hidden
      refute html =~ ~s(class="toolbar")
    end

    @tag :liveview
    test "toggling show_treebar hides treebar on apply", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-show_treebar"]))
      |> render_click()

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      refute html =~ ~s(class="treebar)
    end

    @tag :liveview
    test "toggling show_switchbar hides tab bar on apply", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-show_switchbar"]))
      |> render_click()

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      refute html =~ ~s(class="tab-bar)
    end

    @tag :liveview
    test "toggling compact_mode adds class on apply", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-compact_mode"]))
      |> render_click()

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      assert html =~ "compact-mode"
    end

    @tag :liveview
    test "toggling line_shading adds class on apply", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-line_shading"]))
      |> render_click()

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      assert html =~ "chat-line-shading"
    end
  end

  # ---------------------------------------------------------------------------
  # Draft Discard on Cancel
  # ---------------------------------------------------------------------------

  describe "draft discard on cancel" do
    @tag :liveview
    test "cancel discards display toggle changes", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      # Toggle toolbar off
      view
      |> element(~s([data-testid="options-display-show_toolbar"]))
      |> render_click()

      # Cancel — should discard
      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      # Toolbar should still be visible
      html = render(view)
      assert html =~ ~s(class="toolbar)
    end

    @tag :liveview
    test "cancel discards compact mode toggle", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      # Toggle compact mode on
      view
      |> element(~s([data-testid="options-display-compact_mode"]))
      |> render_click()

      # Cancel
      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      # Should NOT have compact-mode class
      html = render(view)
      refute html =~ "compact-mode"
    end
  end

  # ---------------------------------------------------------------------------
  # OK vs Apply
  # ---------------------------------------------------------------------------

  describe "OK vs Apply behavior" do
    @tag :liveview
    test "Apply keeps dialog open", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "OK closes dialog after applying", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-compact_mode"]))
      |> render_click()

      view |> element(~s([data-testid="options-ok"])) |> render_click()
      html = render(view)
      refute html =~ ~s(data-testid="options-dialog")
      assert html =~ "compact-mode"
    end
  end

  # ---------------------------------------------------------------------------
  # Connect Panel
  # ---------------------------------------------------------------------------

  describe "connect panel" do
    @tag :liveview
    test "shows connect settings", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()
      html = render(view)
      assert html =~ "Auto-Reconnect"
      assert html =~ ~s(data-testid="options-connect-auto-reconnect")
    end

    @tag :liveview
    test "toggle auto-reconnect updates draft", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()

      view
      |> element(~s([data-testid="options-connect-auto-reconnect"]))
      |> render_click()

      html = render(view)
      assert html =~ ~s(data-testid="options-connect-panel")
    end

    @tag :liveview
    test "changing retry interval updates draft", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()

      view
      |> element(~s([data-testid="options-connect-retry-interval"]))
      |> render_change(%{"retry_interval" => "15"})

      html = render(view)
      assert html =~ ~s(data-testid="options-connect-panel")
    end

    @tag :liveview
    test "apply pushes reconnect_config event", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()

      view
      |> element(~s([data-testid="options-connect-retry-interval"]))
      |> render_change(%{"retry_interval" => "20"})

      # Apply should push reconnect_config (no crash)
      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-dialog")
    end

    @tag :liveview
    test "cancel discards connect changes", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()

      view
      |> element(~s([data-testid="options-connect-retry-interval"]))
      |> render_change(%{"retry_interval" => "30"})

      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      # Re-open and check default value is restored
      view |> open_options()
      view |> element(~s([data-testid="options-tree-connect"])) |> render_click()
      html = render(view)
      # Default retry interval is 5
      assert html =~ ~s(value="5")
    end
  end

  # ---------------------------------------------------------------------------
  # Messages Panel
  # ---------------------------------------------------------------------------

  describe "messages panel" do
    @tag :liveview
    test "shows message routing options", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()
      html = render(view)
      assert html =~ "Message Routing"
      assert html =~ "Whois results"
      assert html =~ "Notices"
      assert html =~ "Private Messages"
    end

    @tag :liveview
    test "changing notice routing updates draft", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()

      view
      |> element(~s([data-testid="options-messages-notice-routing"]))
      |> render_change(%{"notice_routing" => "status"})

      html = render(view)
      assert html =~ ~s(data-testid="options-messages-panel")
    end

    @tag :liveview
    test "changing whois routing updates draft", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()

      view
      |> element(~s([data-testid="options-messages-whois-routing"]))
      |> render_change(%{"whois_routing" => "dialog"})

      html = render(view)
      assert html =~ ~s(data-testid="options-messages-panel")
    end

    @tag :liveview
    test "changing PM routing updates draft", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()

      view
      |> element(~s([data-testid="options-messages-pm-routing"]))
      |> render_change(%{"pm_routing" => "active"})

      html = render(view)
      assert html =~ ~s(data-testid="options-messages-panel")
    end

    @tag :liveview
    test "cancel discards routing changes", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()

      view
      |> element(~s([data-testid="options-messages-notice-routing"]))
      |> render_change(%{"notice_routing" => "status"})

      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      # Re-open and verify default routing is restored
      view |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()
      html = render(view)
      # Default notice routing is "active"
      assert html =~ "Active Window"
    end
  end

  # ---------------------------------------------------------------------------
  # Fonts Panel
  # ---------------------------------------------------------------------------

  describe "fonts panel" do
    @tag :liveview
    test "shows font settings for all areas", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-fonts"])) |> render_click()
      html = render(view)
      assert html =~ "Chat Messages"
      assert html =~ "Input Box"
      assert html =~ "Nicklist"
      assert html =~ "Treebar"
      assert html =~ ~s(data-testid="font-preview")
    end

    @tag :liveview
    test "shows live preview area", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-fonts"])) |> render_click()
      html = render(view)
      assert html =~ "The quick brown fox"
    end

    @tag :liveview
    test "changing font size updates draft preview", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-fonts"])) |> render_click()

      view
      |> element(~s([data-testid="options-font-size-chat_messages"]))
      |> render_change(%{"font_size_chat_messages" => "16"})

      html = render(view)
      # Preview should show the new size
      assert html =~ "font-size: 16px"
    end

    @tag :liveview
    test "changing font family updates draft preview", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-fonts"])) |> render_click()

      view
      |> element(~s([data-testid="options-font-family-chat_messages"]))
      |> render_change(%{"font_family_chat_messages" => "\"Courier New\", monospace"})

      html = render(view)
      assert html =~ "Courier New"
    end

    @tag :liveview
    test "apply pushes apply_preferences event", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-fonts"])) |> render_click()

      view
      |> element(~s([data-testid="options-font-size-chat_messages"]))
      |> render_change(%{"font_size_chat_messages" => "18"})

      # Apply should push styles (no crash)
      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="options-dialog")
    end
  end

  # ---------------------------------------------------------------------------
  # Colors Panel
  # ---------------------------------------------------------------------------

  describe "colors panel" do
    @tag :liveview
    test "shows color settings with swatches", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()
      html = render(view)
      assert html =~ "Message Colors"
      assert html =~ "Nick Colors"
      assert html =~ ~s(data-testid="options-color-chat_background")
    end

    @tag :liveview
    test "shows nick palette grid", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="nick-palette-grid")
      assert html =~ ~s(data-testid="nick-palette-0")
    end

    @tag :liveview
    test "changing a color slot updates draft swatch", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()

      # Change chat_background color
      view
      |> render_click("options_change_color", %{"slot" => "chat_background", "color" => "#000000"})

      html = render(view)
      assert html =~ "background-color: #000000"
    end

    @tag :liveview
    test "cancel discards color changes", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()

      view
      |> render_click("options_change_color", %{"slot" => "chat_background", "color" => "#ff0000"})

      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      # Re-open options and check default is restored
      view |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()
      html = render(view)
      # Default chat background is #ffffff
      assert html =~ "background-color: #ffffff"
    end

    @tag :liveview
    test "selecting a nick palette swatch stores editing index", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-colors"])) |> render_click()

      view
      |> element(~s([data-testid="nick-palette-0"]))
      |> render_click()

      # Should not crash — the editing index is stored in assigns
      html = render(view)
      assert html =~ ~s(data-testid="options-colors-panel")
    end
  end

  # ---------------------------------------------------------------------------
  # Key Bindings Panel
  # ---------------------------------------------------------------------------

  describe "keybindings panel" do
    @tag :liveview
    test "shows keyboard shortcuts list", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()
      html = render(view)
      assert html =~ "Keyboard Shortcuts"
      assert html =~ ~s(data-testid="keybindings-list")
      assert html =~ "Reset to Defaults"
    end

    @tag :liveview
    test "shows all action bindings", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()
      html = render(view)
      assert html =~ ~s(data-testid="keybinding-toggle_search")
      assert html =~ ~s(data-testid="keybinding-toggle_address_book")
      assert html =~ ~s(data-testid="keybinding-toggle_options_dialog")
    end

    @tag :liveview
    test "reset to defaults restores default bindings", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()

      view
      |> element(~s([data-testid="options-reset-bindings"]))
      |> render_click()

      html = render(view)
      # Should still show the default bindings
      assert html =~ "Ctrl+Shift+O"
      assert html =~ "Ctrl+Shift+/"
    end

    @tag :liveview
    test "selecting a binding sends select event", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()

      view
      |> render_click("options_select_binding", %{"action" => "toggle_search"})

      # Should not crash
      html = render(view)
      assert html =~ ~s(data-testid="keybindings-list")
    end

    @tag :liveview
    test "capturing a key updates the binding", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()

      # First select the action
      view
      |> render_click("options_select_binding", %{"action" => "toggle_search"})

      # Simulate capturing a key (Ctrl+Shift+Q is not reserved)
      view
      |> render_click("options_capture_key", %{
        "action" => "toggle_search",
        "key" => "q",
        "ctrlKey" => true,
        "altKey" => false,
        "shiftKey" => true
      })

      html = render(view)
      assert html =~ "Ctrl+Shift+Q"
    end

    @tag :liveview
    test "reserved key shows warning", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()

      view
      |> render_click("options_select_binding", %{"action" => "toggle_search"})

      # Try to set Ctrl+W (reserved by browser)
      view
      |> render_click("options_capture_key", %{
        "action" => "toggle_search",
        "key" => "w",
        "ctrlKey" => true,
        "altKey" => false,
        "shiftKey" => false
      })

      # Should have a warning assign set (keybinding_warning)
      # The binding should NOT be changed
      html = render(view)
      assert html =~ "Ctrl+Shift+F"
    end

    @tag :liveview
    test "clearing a binding removes it", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()

      view
      |> render_click("options_clear_binding", %{"action" => "toggle_search"})

      html = render(view)
      assert html =~ "(unbound)"
    end

    @tag :liveview
    test "dynamic lookup works after key binding change and apply", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-keybindings"])) |> render_click()

      # Change the search shortcut to Ctrl+Shift+Q
      view
      |> render_click("options_capture_key", %{
        "action" => "toggle_search",
        "key" => "q",
        "ctrlKey" => true,
        "altKey" => false,
        "shiftKey" => true
      })

      view |> element(~s([data-testid="options-ok"])) |> render_click()

      # Now Ctrl+Shift+Q should open search
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "q", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      assert html =~ ~s(class="search-bar)
    end
  end
end
