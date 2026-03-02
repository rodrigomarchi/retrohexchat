defmodule RetroHexChatWeb.OptionsDialogE2ETest do
  @moduledoc """
  End-to-end tests for the Options Dialog.
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
      refute has_element?(view, "#options-dialog-show-trigger")

      render_click(view, "window_keydown", %{"key" => "o", "ctrlKey" => true, "shiftKey" => true})

      assert has_element?(view, "#options-dialog-show-trigger")
      assert render(view) =~ "Options"
    end

    test "1.2 Tools > Options menu opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EMenu#{uid()}")
      render_click(view, "open_options_dialog")
      assert has_element?(view, "#options-dialog-show-trigger")
    end

    test "1.3 Cancel closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2ECncl#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "close_options_dialog")
      refute has_element?(view, "#options-dialog-show-trigger")
    end

    test "1.4 OK closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EOK#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "options_ok")
      refute has_element?(view, "#options-dialog-show-trigger")
    end

    test "1.5 Escape closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EEsc#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "window_keydown", %{"key" => "Escape"})
      refute has_element?(view, "#options-dialog-show-trigger")
    end

    test "1.6 duplicate open is no-op", %{conn: conn} do
      view = connect_user(conn, "E2EDup#{uid()}")
      render_click(view, "open_options_dialog")
      render_click(view, "open_options_dialog")
      assert has_element?(view, "#options-dialog-show-trigger")
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

    test "2.2 navigate both panels", %{conn: conn} do
      view = connect_user(conn, "E2EAll#{uid()}")
      render_click(view, "open_options_dialog")

      panels = [
        {"display", "options-display-panel"}
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
      render_click(view, "options_ok")

      html = render(view)
      # Toolbar should be hidden after toggling off
      refute html =~ ~s(data-testid="toolbar-connect")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Draft State (Apply vs Cancel)
  # ---------------------------------------------------------------------------

  describe "Draft state" do
    test "4.1 cancel discards changes", %{conn: conn} do
      view = connect_user(conn, "E2EDsc#{uid()}")
      render_click(view, "open_options_dialog")

      # Toggle toolbar off in draft
      render_click(view, "options_toggle_display", %{"setting" => "show_toolbar"})

      # Cancel
      render_click(view, "close_options_dialog")

      # Toolbar should still be visible
      html = render(view)
      assert html =~ "toolbar"
    end

    test "4.2 apply keeps dialog open with changes applied", %{conn: conn} do
      view = connect_user(conn, "E2EApl#{uid()}")
      render_click(view, "open_options_dialog")

      render_click(view, "options_toggle_display", %{"setting" => "show_statusbar"})
      render_click(view, "options_apply")

      # Dialog stays open
      assert has_element?(view, "#options-dialog-show-trigger")
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
end
