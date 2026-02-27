defmodule RetroHexChatWeb.ChatLiveOptionsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp connect_user(conn, nick \\ nil) do
    nick = nick || "Opt#{uid()}"
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
    test "duplicate open_options_dialog event does not crash", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      assert render(view) =~ ~s(data-testid="options-dialog")

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
    test "selected tree item has tree-item-selected class", %{conn: conn} do
      view = connect_user(conn) |> open_options()
      html = render(view)
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

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      refute html =~ ~s(class="toolbar")
    end

    @tag :liveview
    test "toggling show_conversations hides conversations on apply", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-show_conversations"]))
      |> render_click()

      view |> element(~s([data-testid="options-apply"])) |> render_click()
      html = render(view)
      refute html =~ ~s(class="conversations")
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
  end

  # ---------------------------------------------------------------------------
  # Draft Discard on Cancel
  # ---------------------------------------------------------------------------

  describe "draft discard on cancel" do
    @tag :liveview
    test "cancel discards display toggle changes", %{conn: conn} do
      view = connect_user(conn) |> open_options()

      view
      |> element(~s([data-testid="options-display-show_toolbar"]))
      |> render_click()

      view |> element(~s([data-testid="options-cancel"])) |> render_click()

      html = render(view)
      assert html =~ ~s(class="toolbar)
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
      |> element(~s([data-testid="options-display-show_statusbar"]))
      |> render_click()

      view |> element(~s([data-testid="options-ok"])) |> render_click()
      html = render(view)
      refute html =~ ~s(data-testid="options-dialog")
    end
  end
end
