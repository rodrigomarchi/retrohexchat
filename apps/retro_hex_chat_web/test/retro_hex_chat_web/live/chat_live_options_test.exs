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
    view |> element(~s([data-testid="toolbar-settings"])) |> render_click()
    view
  end

  # ---------------------------------------------------------------------------
  # Dialog Open / Close
  # ---------------------------------------------------------------------------

  describe "Options dialog open/close" do
    @tag :liveview
    test "opens via toolbar Settings button", %{conn: conn} do
      view = connect_user(conn)
      view |> element(~s([data-testid="toolbar-settings"])) |> render_click()
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
      view |> element(~s([data-testid="toolbar-settings"])) |> render_click()
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
  # Messages Panel
  # ---------------------------------------------------------------------------

  describe "messages panel" do
    @tag :liveview
    test "shows message routing options", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      view |> element(~s([data-testid="options-tree-messages"])) |> render_click()
      html = render(view)
      assert html =~ "Message Routing"
      assert html =~ "Notices"
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
