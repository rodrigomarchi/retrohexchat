defmodule RetroHexChatWeb.OptionsDialogE2ETest do
  @moduledoc """
  End-to-end tests for the Options Dialog (021).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ---------------------------------------------------------------------------
  # 1. Dialog Open / Close
  # ---------------------------------------------------------------------------

  describe "Dialog open/close" do
    test "1.1 Ctrl+Shift+O opens options dialog", %{conn: conn} do
      view = connect_user(conn, "E2EOpt#{uid()}")
      refute render(view) =~ "options-dialog-overlay"

      html =
        view
        |> element("#app-container")
        |> render_keydown(%{"key" => "o", "ctrlKey" => true, "shiftKey" => true})

      assert html =~ "options-dialog-overlay"
      assert html =~ "Options"
    end

    test "1.2 Tools > Options menu opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EMenu#{uid()}")
      html = render_click(view, "open_options_dialog")
      assert html =~ "options-dialog-overlay"
    end

    test "1.3 Cancel closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2ECncl#{uid()}")
      render_click(view, "open_options_dialog")
      html = view |> element(~s([data-testid="options-cancel"])) |> render_click()
      refute html =~ "options-dialog-overlay"
    end

    test "1.4 OK closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EOK#{uid()}")
      render_click(view, "open_options_dialog")
      html = view |> element(~s([data-testid="options-ok"])) |> render_click()
      refute html =~ "options-dialog-overlay"
    end

    test "1.5 Escape closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EEsc#{uid()}")
      render_click(view, "open_options_dialog")

      html =
        view
        |> element("#app-container")
        |> render_keydown(%{"key" => "Escape"})

      refute html =~ "options-dialog-overlay"
    end

    test "1.6 duplicate open is no-op", %{conn: conn} do
      view = connect_user(conn, "E2EDup#{uid()}")
      render_click(view, "open_options_dialog")
      html = render_click(view, "open_options_dialog")
      assert html =~ "options-dialog-overlay"
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Panel Navigation
  # ---------------------------------------------------------------------------

  describe "Panel navigation" do
    test "2.1 default panel is Display", %{conn: conn} do
      view = connect_user(conn, "E2ENav#{uid()}")
      html = render_click(view, "open_options_dialog")
      assert html =~ ~s(data-testid="options-display-panel")
    end

    test "2.2 click tree item switches panel", %{conn: conn} do
      view = connect_user(conn, "E2EPnl#{uid()}")
      render_click(view, "open_options_dialog")

      html = render_click(view, "options_select_panel", %{"panel" => "messages"})
      assert html =~ ~s(data-testid="options-messages-panel")
      refute html =~ ~s(data-testid="options-display-panel")
    end

    test "2.3 navigate all 4 panels", %{conn: conn} do
      view = connect_user(conn, "E2EAll#{uid()}")
      render_click(view, "open_options_dialog")

      panels = [
        {"messages", "options-messages-panel"},
        {"display", "options-display-panel"},
        {"keybindings", "options-keybindings-panel"},
        {"notifications", "options-notifications-panel"}
      ]

      for {panel_id, testid} <- panels do
        html = render_click(view, "options_select_panel", %{"panel" => panel_id})
        assert html =~ testid, "Panel #{panel_id} should show #{testid}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Display Panel
  # ---------------------------------------------------------------------------

  describe "Display panel" do
    test "3.1 toggle toolbar visibility", %{conn: conn} do
      view = connect_user(conn, "E2ETbar#{uid()}")
      html = render(view)
      assert html =~ "toolbar"

      render_click(view, "open_options_dialog")
      render_click(view, "options_toggle_display", %{"setting" => "show_toolbar"})
      html = view |> element(~s([data-testid="options-ok"])) |> render_click()

      refute html =~ ~s(data-testid="toolbar-connect")
    end

    test "3.2 toggle line shading", %{conn: conn} do
      view = connect_user(conn, "E2EShad#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "options_toggle_display", %{"setting" => "line_shading"})
      html = view |> element(~s([data-testid="options-apply"])) |> render_click()

      assert html =~ "chat-line-shading"
    end

    test "3.3 toggle compact mode", %{conn: conn} do
      view = connect_user(conn, "E2ECmp#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "options_toggle_display", %{"setting" => "compact_mode"})
      html = view |> element(~s([data-testid="options-ok"])) |> render_click()

      assert html =~ "compact-mode"
    end
  end

  # ---------------------------------------------------------------------------
  # 4. IRC Messages Panel
  # ---------------------------------------------------------------------------

  describe "IRC Messages panel" do
    test "4.1 shows notice routing selector", %{conn: conn} do
      view = connect_user(conn, "E2EMsg#{uid()}")
      render_click(view, "open_options_dialog")
      html = render_click(view, "options_select_panel", %{"panel" => "messages"})

      assert html =~ ~s(data-testid="options-messages-notice-routing")
    end

    test "4.2 change notice routing to status", %{conn: conn} do
      view = connect_user(conn, "E2ENRt#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "options_select_panel", %{"panel" => "messages"})

      render_click(view, "options_change_routing", %{"notice_routing" => "status"})
      html = view |> element(~s([data-testid="options-ok"])) |> render_click()
      refute html =~ "options-dialog-overlay"
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Key Bindings Panel
  # ---------------------------------------------------------------------------

  describe "Key Bindings panel" do
    test "5.1 shows all action bindings", %{conn: conn} do
      view = connect_user(conn, "E2EKB#{uid()}")
      render_click(view, "open_options_dialog")
      html = render_click(view, "options_select_panel", %{"panel" => "keybindings"})

      assert html =~ ~s(data-testid="keybindings-list")
      assert html =~ "Address Book"
      assert html =~ "Search"
      assert html =~ "Options"
    end

    test "5.2 reset to defaults", %{conn: conn} do
      view = connect_user(conn, "E2ERst#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "options_select_panel", %{"panel" => "keybindings"})

      html = render_click(view, "options_reset_bindings")
      assert html =~ ~s(data-testid="keybindings-list")
    end

    test "5.3 reserved key does not change binding", %{conn: conn} do
      view = connect_user(conn, "E2ERes#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "options_select_panel", %{"panel" => "keybindings"})

      render_click(view, "options_select_binding", %{"action" => "toggle_search"})

      render_click(view, "options_capture_key", %{
        "action" => "toggle_search",
        "key" => "w",
        "ctrlKey" => true,
        "altKey" => false,
        "shiftKey" => false
      })

      # Binding should remain as Ctrl+Shift+F (not changed to Ctrl+W)
      html = render(view)
      assert html =~ "Ctrl+Shift+F"
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Draft State (Apply vs Cancel)
  # ---------------------------------------------------------------------------

  describe "Draft state" do
    test "6.1 cancel discards changes", %{conn: conn} do
      view = connect_user(conn, "E2EDsc#{uid()}")
      render_click(view, "open_options_dialog")

      # Toggle compact mode in draft
      render_click(view, "options_toggle_display", %{"setting" => "compact_mode"})

      # Cancel
      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      # Compact mode should NOT be applied
      html = render(view)
      refute html =~ "compact-mode"
    end

    test "6.2 apply keeps dialog open with changes applied", %{conn: conn} do
      view = connect_user(conn, "E2EApl#{uid()}")
      render_click(view, "open_options_dialog")

      render_click(view, "options_toggle_display", %{"setting" => "line_shading"})
      html = view |> element(~s([data-testid="options-apply"])) |> render_click()

      # Dialog stays open
      assert html =~ "options-dialog-overlay"
      # Change is applied
      assert html =~ "chat-line-shading"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid, do: rem(System.unique_integer([:positive]), 100_000)
end
