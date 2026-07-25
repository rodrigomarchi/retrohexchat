defmodule RetroHexChatWeb.NickColorsFeatureTest do
  @moduledoc """
  End-to-end tests for the Address Book feature (003).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # The Address Book is a stateful island; events target the component, so fire
  # them element-based (scoped to the dialog — notify_* collide with the
  # standalone Notify dialog).
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

  # ══════════════════════════════════════════════════════════════
  # US1 — Dialog Shell (T042)
  # ══════════════════════════════════════════════════════════════

  describe "US4: Nick Colors Tab" do
    test "add nick color override", %{conn: conn} do
      view = connect_user(conn, "E2ENcAdd#{uid()}")
      render_click(view, "open_nick_colors_dialog")

      # Open add dialog
      ab_click(view, "nick_color_add_dialog")
      assert render(view) =~ "Add Nick Color"

      # Submit with color 4 (Red)
      ab_form(view, "nick-color-add-form", %{"nickname" => "ColorBud", "color_index" => "4"})
      html = render(view)

      assert html =~ "ColorBud"
      assert html =~ "Red"
      assert html =~ "irc-bg-4"
    end

    test "edit color", %{conn: conn} do
      view = connect_user(conn, "E2ENcEdit#{uid()}")
      render_click(view, "open_nick_colors_dialog")

      # Add with Red (4)
      ab_click(view, "nick_color_add_dialog")
      ab_form(view, "nick-color-add-form", %{"nickname" => "EditClr", "color_index" => "4"})
      assert render(view) =~ "Red"

      # Select and edit to Blue (12)
      ab_select(view, "nick_color_select", "EditClr")
      ab_click(view, "nick_color_edit_dialog")
      assert render(view) =~ "Edit Nick Color"

      ab_form(view, "nick-color-edit-form", %{"nickname" => "EditClr", "color_index" => "12"})
      html = render(view)

      assert html =~ "Blue"
      assert html =~ "irc-bg-12"
    end

    test "remove override", %{conn: conn} do
      view = connect_user(conn, "E2ENcRm#{uid()}")
      render_click(view, "open_nick_colors_dialog")

      # Add
      ab_click(view, "nick_color_add_dialog")
      ab_form(view, "nick-color-add-form", %{"nickname" => "RmClr", "color_index" => "4"})
      assert render(view) =~ "RmClr"

      # Select and remove
      ab_select(view, "nick_color_select", "RmClr")
      ab_click(view, "nick_color_remove")

      html = render(view)
      refute html =~ "nick-color-entry-RmClr"
      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US5 + Context Menu (T046)
  # ══════════════════════════════════════════════════════════════

  # ══════════════════════════════════════════════════════════════
  # Private Helpers
  # ══════════════════════════════════════════════════════════════

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
