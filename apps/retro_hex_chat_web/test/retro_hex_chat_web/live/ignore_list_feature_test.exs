defmodule RetroHexChatWeb.IgnoreListFeatureTest do
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
    view |> element("#ignore-list-dialog-mount [phx-click='#{event}']") |> render_click()
  end

  defp ab_select(view, event, nick) do
    view
    |> element("#ignore-list-dialog-mount [phx-click='#{event}'][phx-value-nickname='#{nick}']")
    |> render_click()
  end

  defp ab_form(view, testid, params) do
    view |> element("[data-testid='#{testid}']") |> render_submit(params)
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Dialog Shell (T042)
  # ══════════════════════════════════════════════════════════════

  describe "US5: Control Tab and Context Menu" do
    test "control tab placeholder message", %{conn: conn} do
      view = connect_user(conn, "E2ECtrl#{uid()}")
      render_click(view, "open_ignore_list_dialog")

      html = render(view)
      assert html =~ "No ignored users. Click Add to ignore a nickname."
    end

    test "context menu 'Add to Contacts' adds nick to contacts", %{conn: conn} do
      view = connect_user(conn, "E2ECtxAdd#{uid()}")

      # Trigger context menu on a nick
      render_click(view, "nick_right_click", %{
        "nick" => "CtxFriend",
        "x" => "100",
        "y" => "200"
      })

      # Click "Add to Contacts" via nicklist context menu action dispatcher
      render_click(view, "nicklist_context_action", %{"action" => "context_add_contact"})

      # Open address book and verify contact is present
      render_click(view, "toggle_address_book")
      html = render(view)
      assert html =~ "CtxFriend"
    end

    test "context menu 'Set Nick Color' -> color picker -> color applied", %{conn: conn} do
      view = connect_user(conn, "E2ECtxClr#{uid()}")

      # Trigger context menu
      render_click(view, "nick_right_click", %{
        "nick" => "ClrTarget",
        "x" => "100",
        "y" => "200"
      })

      # Click "Set Nick Color" via nicklist context menu action dispatcher
      render_click(view, "nicklist_context_action", %{"action" => "context_set_nick_color"})
      html = render(view)
      assert html =~ "color-swatch-"

      # Pick a color (Red = 4) via nicklist context menu action dispatcher.
      # The color swatch carries the target nick as phx-value-nick.
      render_click(view, "nicklist_context_action", %{
        "action" => "context_pick_color",
        "color_index" => "4",
        "nick" => "ClrTarget"
      })

      # Verify in nick colors tab
      render_click(view, "open_ignore_list_dialog")
      html = render(view)

      assert html =~ "ClrTarget"
      assert html =~ "Red"
    end
  end

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
