defmodule RetroHexChatWeb.NotifyListFeatureTest do
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
    view |> element("#notify-list-dialog-mount [phx-click='#{event}']") |> render_click()
  end

  defp ab_select(view, event, nick) do
    view
    |> element("#notify-list-dialog-mount [phx-click='#{event}'][phx-value-nickname='#{nick}']")
    |> render_click()
  end

  defp ab_form(view, testid, params) do
    view |> element("[data-testid='#{testid}']") |> render_submit(params)
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Dialog Shell (T042)
  # ══════════════════════════════════════════════════════════════

  describe "US3: Notify Tab" do
    test "notify tab shows existing buddies added via /notify command", %{conn: conn} do
      view = connect_user(conn, "E2ENtSync#{uid()}")

      # Add buddy via /notify command
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/notify add SyncBud"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)

      # Open address book and switch to notify tab
      render_click(view, "toggle_notify_list")

      html = render(view)
      assert html =~ "SyncBud"
    end

    test "add buddy via notify tab", %{conn: conn} do
      view = connect_user(conn, "E2ENtAdd#{uid()}")
      render_click(view, "toggle_notify_list")

      # Open add dialog
      ab_click(view, "notify_add_dialog")
      assert render(view) =~ "Add Notify Entry"

      # Submit
      ab_form(view, "notify-add-form", %{"nickname" => "NtBuddy", "note" => "my notify buddy"})
      html = render(view)

      assert html =~ "NtBuddy"
      assert html =~ "my notify buddy"
    end

    test "remove buddy via notify tab", %{conn: conn} do
      view = connect_user(conn, "E2ENtRm#{uid()}")
      render_click(view, "toggle_notify_list")

      # Add then select and remove
      ab_click(view, "notify_add_dialog")
      ab_form(view, "notify-add-form", %{"nickname" => "RmNotify", "note" => ""})
      assert render(view) =~ "RmNotify"

      ab_select(view, "notify_select", "RmNotify")
      ab_click(view, "notify_remove")

      html = render(view)
      refute html =~ "notify-list-row-RmNotify"
      assert html =~ "No notify nicks yet. Add a nick to track online status."
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Nick Colors Tab (T045)
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
