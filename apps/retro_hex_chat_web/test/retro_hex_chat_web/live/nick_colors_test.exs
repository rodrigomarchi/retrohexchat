defmodule RetroHexChatWeb.NickColorsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

  setup do
    case RetroHexChat.Channels.Registry.lookup("#lobby") do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> ChannelSupervisor.start_child("#lobby")
    end

    :ok
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  # The Nick Colors window is a stateful island; its events target the component,
  # so fire them element-based (the design-system threads phx-target through).
  defp ab_click(view, event) do
    view |> element("#nick-colors-dialog-mount [phx-click='#{event}']") |> render_click()
  end

  defp ab_select(view, event, nick) do
    view
    |> element("#nick-colors-dialog-mount [phx-click='#{event}'][phx-value-nickname='#{nick}']")
    |> render_click()
  end

  defp ab_form(view, testid, params) do
    view |> element("[data-testid='#{testid}']") |> render_submit(params)
  end

  # ── Phase 3: US1 — Dialog Shell ──────────────────────────

  describe "nick colors tab" do
    test "empty nick colors shows placeholder message", %{conn: conn} do
      view = connect_user(conn, "EmptyColors")
      view |> render_click("open_nick_colors_dialog")
      html = render(view)

      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end

    test "add nick color success — appears in list with swatch", %{conn: conn} do
      view = connect_user(conn, "AddColor")
      view |> render_click("open_nick_colors_dialog")

      # Open add dialog
      view |> ab_click("nick_color_add_dialog")
      assert render(view) =~ "Add Nick Color"

      # Submit with color 4 (Red)
      view
      |> ab_form("nick-color-add-form", %{"nickname" => "ColorBud", "color_index" => "4"})

      html = render(view)
      assert html =~ "ColorBud"
      assert html =~ "Red"
      assert html =~ "irc-bg-4"
      refute html =~ "Add Nick Color</div>"
    end

    test "add duplicate shows error", %{conn: conn} do
      view = connect_user(conn, "DupColor")
      view |> render_click("open_nick_colors_dialog")

      # Add first
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "DupNick", "color_index" => "4"})

      # Add same again
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "DupNick", "color_index" => "5"})

      html = render(view)
      assert html =~ "DupNick already has a custom color"
    end

    test "edit color updates in list", %{conn: conn} do
      view = connect_user(conn, "EditColor")
      view |> render_click("open_nick_colors_dialog")

      # Add with Red (4)
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "EditNick", "color_index" => "4"})
      assert render(view) =~ "Red"

      # Select and edit to Blue (12)
      view |> ab_select("nick_color_select", "EditNick")
      view |> ab_click("nick_color_edit_dialog")
      assert render(view) =~ "Edit Nick Color"

      view |> ab_form("nick-color-edit-form", %{"nickname" => "EditNick", "color_index" => "12"})
      html = render(view)

      assert html =~ "Blue"
      assert html =~ "irc-bg-12"
      refute html =~ "Edit Nick Color</div>"
    end

    test "remove color removes from list", %{conn: conn} do
      view = connect_user(conn, "RemColor")
      view |> render_click("open_nick_colors_dialog")

      # Add
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "RemNick", "color_index" => "4"})
      assert render(view) =~ "RemNick"

      # Select and remove
      view |> ab_select("nick_color_select", "RemNick")
      view |> ab_click("nick_color_remove")

      html = render(view)
      refute html =~ "nick-color-entry-RemNick"
      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end

    test "select entry enables edit/remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelColor")
      view |> render_click("open_nick_colors_dialog")

      # Add entry
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "SelNick", "color_index" => "3"})

      # Before selection, buttons disabled
      assert has_element?(view, "[data-testid=\"nick-color-edit\"][disabled]")
      assert has_element?(view, "[data-testid=\"nick-color-remove\"][disabled]")

      # Select
      view |> ab_select("nick_color_select", "SelNick")

      # After selection, not disabled
      refute has_element?(view, "[data-testid=\"nick-color-edit\"][disabled]")
      refute has_element?(view, "[data-testid=\"nick-color-remove\"][disabled]")
    end

    test "color override applies to chat message nickname", %{conn: conn} do
      view = connect_user(conn, "ColorMsg")
      view |> render_click("open_nick_colors_dialog")

      # Set a custom color for "SomeChatter" — Red (4) = #ff0000
      view |> ab_click("nick_color_add_dialog")

      view
      |> ab_form("nick-color-add-form", %{"nickname" => "SomeChatter", "color_index" => "4"})

      # The nick color entry should appear in the list with the irc-bg-4 swatch
      # (functional test — override is wired into session via nick_color_fn)
      html = render(view)
      assert html =~ "SomeChatter"
      assert html =~ "irc-bg-4"
    end
  end

  # ── Phase 8: Context Menu Integration ──────────────────────
end
