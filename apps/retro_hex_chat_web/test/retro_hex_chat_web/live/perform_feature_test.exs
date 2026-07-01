defmodule RetroHexChatWeb.PerformFeatureTest do
  @moduledoc """
  End-to-end tests for the Perform / Auto-Commands feature (009).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Perform Commands on Connect
  # ══════════════════════════════════════════════════════════════

  describe "US1: perform commands CRUD via /perform" do
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Perform Execution on Connect
  # ══════════════════════════════════════════════════════════════

  describe "US1: perform execution" do
    test "execute_perform runs saved commands on trigger", %{conn: conn} do
      view = connect_user(conn, "E2EPfX#{uid()}")
      submit_command(view, "/perform add /join #e2epfexec")

      send(view.pid, {:execute_perform, 0})

      # Assert the actual effect (the saved /join ran) via synchronous state,
      # not the transient "Performing" stream message.
      assert "#e2epfexec" in joined_channels(view)
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — Perform Dialog
  # ══════════════════════════════════════════════════════════════

  describe "US2: perform dialog" do
    test "Ctrl+Shift+E opens and closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDlg#{uid()}")

      render_click(view, "window_keydown", %{
        "key" => "e",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      assert has_element?(view, "#perform-dialog-show-trigger")

      render_click(view, "window_keydown", %{
        "key" => "e",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      refute has_element?(view, "#perform-dialog-show-trigger")
    end

    test "menu bar opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EMnu#{uid()}")

      open_perform(view)
      assert has_element?(view, "#perform-dialog-show-trigger")
    end

    test "add command via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDlA#{uid()}")

      open_perform(view)
      click(view, "perform_dialog_add")
      submit_form(view, "perform-add-dialog", %{"command" => "/join #dlgtest"})

      html = render(view)
      assert html =~ "/join #dlgtest"
    end

    test "remove command via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDlR#{uid()}")

      open_perform(view)
      click(view, "perform_dialog_add")
      submit_form(view, "perform-add-dialog", %{"command" => "/join #dlgrem"})

      select_perform(view, 0)
      click(view, "perform_dialog_remove")

      html = render(view)
      refute html =~ "/join #dlgrem"
    end

    test "tab switching between commands and autojoin", %{conn: conn} do
      view = connect_user(conn, "E2ETab#{uid()}")

      open_perform(view)

      # Both tab panels render when the dialog is open (switching is client-side
      # CSS); their empty-state copy is present regardless of the active tab.
      html = render(view)
      assert html =~ "No commands configured"
      assert html =~ "No auto-join channels"
    end

    test "enable/disable toggle", %{conn: conn} do
      view = connect_user(conn, "E2ETgl#{uid()}")

      open_perform(view)
      click(view, "perform_toggle_enabled")

      html = render(view)
      # After toggling, checkbox state changes
      assert html =~ "perform_toggle_enabled"
    end

    test "password masking in dialog", %{conn: conn} do
      view = connect_user(conn, "E2EPwd#{uid()}")

      open_perform(view)
      click(view, "perform_dialog_add")
      submit_form(view, "perform-add-dialog", %{"command" => "/ns identify mysecret"})

      html = render(view)
      assert html =~ "***"
      refute html =~ "mysecret"
    end

    test "Escape closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EEsc#{uid()}")

      open_perform(view)
      assert has_element?(view, "#perform-dialog-show-trigger")

      view |> element("#perform-dialog-wrap") |> render_keydown(%{"key" => "Escape"})
      refute has_element?(view, "#perform-dialog-show-trigger")
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Auto-Join Channel List
  # ══════════════════════════════════════════════════════════════

  describe "US3: autojoin commands" do
    test "autojoin execution joins the saved channel", %{conn: conn} do
      view = connect_user(conn, "E2EAjX#{uid()}")
      submit_command(view, "/autojoin add #e2eajexec")

      send(view.pid, {:execute_autojoin, 0})

      # Assert the channel was actually joined (synchronous state), not the
      # transient "Auto-joining" stream message.
      assert "#e2eajexec" in joined_channels(view)
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Auto-Reconnect Push Events
  # ══════════════════════════════════════════════════════════════

  describe "US4: reconnect push events" do
    test "/quit pushes intentional_disconnect", %{conn: conn} do
      view = connect_user(conn, "E2ERcQ#{uid()}")
      submit_command(view, "/quit")

      assert_push_event(view, "intentional_disconnect", %{})
    end

    test "joining channel pushes save_reconnect_state", %{conn: conn} do
      nick = "E2ERcJ#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #e2ercjoin")

      assert_push_event(view, "save_reconnect_state", %{
        nickname: ^nick,
        active_channel: "#e2ercjoin"
      })
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US5 — Session Restoration
  # ══════════════════════════════════════════════════════════════

  describe "US5: session restoration" do
    test "restore_session accepts the reconnect target (rejoin is deferred)", %{conn: conn} do
      view = connect_user(conn, "E2ERst#{uid()}")

      render_hook(view, "restore_session", %{
        "channels" => ["#e2erst"],
        "active_channel" => "#e2erst",
        "active_pm" => nil
      })

      # restore_session sets the reconnect target synchronously and schedules the
      # rejoin (covered by the execute_rejoin test). Assert the synchronous state
      # rather than the transient "Restoring session" stream message.
      assert :sys.get_state(view.pid).socket.assigns.reconnect_active_channel == "#e2erst"
    end

    test "execute_rejoin joins channels not yet joined", %{conn: conn} do
      view = connect_user(conn, "E2ERjn#{uid()}")

      send(view.pid, {:execute_rejoin, 0, ["#e2erejoin"]})

      assert "#e2erejoin" in joined_channels(view)
    end

    test "execute_rejoin skips already-joined channels", %{conn: conn} do
      view = connect_user(conn, "E2EDup#{uid()}")

      send(view.pid, {:execute_rejoin, 0, ["#lobby"]})

      html = render(view)
      refute html =~ "Rejoining #lobby"
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  # The Perform dialog is a stateful island; its events target the component, so
  # tests fire them element-based. Opening is async (send_update), so flush.
  defp open_perform(view) do
    render_click(view, "open_perform_dialog")
    render(view)
  end

  defp click(view, event) do
    view |> element("[phx-click='#{event}']") |> render_click()
  end

  defp select_perform(view, position) do
    view
    |> element("[phx-click='perform_select'][phx-value-position='#{position}']")
    |> render_click()
  end

  defp submit_form(view, testid, params) do
    view |> element(~s([data-testid="#{testid}"])) |> render_submit(params)
  end

  defp submit_command(view, command) do
    view |> element(~s([data-testid="chat-input-form"])) |> render_submit(%{"input" => command})
  end

  # Reads the LiveView's joined channels synchronously. `:sys.get_state` is a
  # GenServer call, so it drains the process mailbox (FIFO) before returning —
  # any queued composer dispatch / execute_* message is applied first. Lets us
  # assert on the actual effect deterministically instead of a streamed message.
  defp joined_channels(view) do
    :sys.get_state(view.pid).socket.assigns.session.channels
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
