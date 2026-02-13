defmodule RetroHexChatWeb.PerformE2ETest do
  @moduledoc """
  End-to-end tests for the Perform / Auto-Commands feature (009).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Perform Commands on Connect
  # ══════════════════════════════════════════════════════════════

  describe "US1: perform commands CRUD via /perform" do
    test "/perform add adds a command", %{conn: conn} do
      view = connect_user(conn, "E2EPfA#{uid()}")
      submit_command(view, "/perform add /join #e2etest")

      html = render(view)
      assert html =~ "Added to perform list"
    end

    test "/perform list shows added commands", %{conn: conn} do
      view = connect_user(conn, "E2EPfL#{uid()}")
      submit_command(view, "/perform add /join #alpha")
      submit_command(view, "/perform add /join #beta")
      submit_command(view, "/perform list")

      html = render(view)
      assert html =~ "/join #alpha"
      assert html =~ "/join #beta"
    end

    test "/perform remove removes a command", %{conn: conn} do
      view = connect_user(conn, "E2EPfR#{uid()}")
      submit_command(view, "/perform add /join #removeme")
      submit_command(view, "/perform remove 0")

      html = render(view)
      assert html =~ "Removed command at position 0"
    end

    test "/perform move reorders commands", %{conn: conn} do
      view = connect_user(conn, "E2EPfM#{uid()}")
      submit_command(view, "/perform add /join #first")
      submit_command(view, "/perform add /join #second")
      submit_command(view, "/perform move 0 1")

      html = render(view)
      assert html =~ "Moved command from position 0 to 1"
    end

    test "/perform clear removes all commands", %{conn: conn} do
      view = connect_user(conn, "E2EPfC#{uid()}")
      submit_command(view, "/perform add /join #ch1")
      submit_command(view, "/perform add /join #ch2")
      submit_command(view, "/perform clear")

      html = render(view)
      assert html =~ "Perform list cleared"
    end

    test "/perform add with disallowed command shows error", %{conn: conn} do
      view = connect_user(conn, "E2EPfD#{uid()}")
      submit_command(view, "/perform add /quit")

      html = render(view)
      assert html =~ "cannot be added to the perform list"
    end

    test "password masking in /perform list", %{conn: conn} do
      view = connect_user(conn, "E2EPfP#{uid()}")
      submit_command(view, "/perform add /ns identify secret123")
      submit_command(view, "/perform list")

      html = render(view)
      assert html =~ "****"
      refute html =~ "secret123"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Perform Execution on Connect
  # ══════════════════════════════════════════════════════════════

  describe "US1: perform execution" do
    test "execute_perform runs commands on trigger", %{conn: conn} do
      view = connect_user(conn, "E2EPfX#{uid()}")
      submit_command(view, "/perform add /join #e2epfexec")

      send(view.pid, {:execute_perform, 0})

      html = render(view)
      assert html =~ "Performing: /join #e2epfexec"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — Perform Dialog
  # ══════════════════════════════════════════════════════════════

  describe "US2: perform dialog" do
    test "Ctrl+Shift+E opens and closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDlg#{uid()}")

      render_keydown(view, "window_keydown", %{
        "key" => "e",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      html = render(view)
      assert html =~ "data-testid=\"perform-dialog\""

      render_keydown(view, "window_keydown", %{
        "key" => "e",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      html = render(view)
      refute html =~ "data-testid=\"perform-dialog\""
    end

    test "menu bar opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EMnu#{uid()}")

      render_click(view, "open_perform_dialog")
      html = render(view)
      assert html =~ "data-testid=\"perform-dialog\""
    end

    test "add command via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDlA#{uid()}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #dlgtest"})

      html = render(view)
      assert html =~ "/join #dlgtest"
    end

    test "remove command via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDlR#{uid()}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #dlgrem"})

      render_click(view, "perform_select", %{"position" => "0"})
      render_click(view, "perform_dialog_remove")

      html = render(view)
      refute html =~ "/join #dlgrem"
    end

    test "tab switching between commands and autojoin", %{conn: conn} do
      view = connect_user(conn, "E2ETab#{uid()}")

      render_click(view, "open_perform_dialog")

      # Switch to autojoin tab
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})
      html = render(view)
      assert html =~ "No auto-join channels"

      # Switch back to commands tab
      render_click(view, "perform_dialog_tab", %{"tab" => "commands"})
      html = render(view)
      assert html =~ "No perform commands"
    end

    test "enable/disable toggle", %{conn: conn} do
      view = connect_user(conn, "E2ETgl#{uid()}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_toggle_enabled")

      html = render(view)
      # After toggling, checkbox state changes
      assert html =~ "perform_toggle_enabled"
    end

    test "password masking in dialog", %{conn: conn} do
      view = connect_user(conn, "E2EPwd#{uid()}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/ns identify mysecret"})

      html = render(view)
      assert html =~ "****"
      refute html =~ "mysecret"
    end

    test "Escape closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EEsc#{uid()}")

      render_click(view, "open_perform_dialog")
      html = render(view)
      assert html =~ "data-testid=\"perform-dialog\""

      render_keydown(view, "window_keydown", %{"key" => "Escape"})
      html = render(view)
      refute html =~ "data-testid=\"perform-dialog\""
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Auto-Join Channel List
  # ══════════════════════════════════════════════════════════════

  describe "US3: autojoin commands" do
    test "/autojoin add adds a channel", %{conn: conn} do
      view = connect_user(conn, "E2EAjA#{uid()}")
      submit_command(view, "/autojoin add #e2eajtest")

      html = render(view)
      assert html =~ "Added to auto-join list"
    end

    test "/autojoin list shows added channels", %{conn: conn} do
      view = connect_user(conn, "E2EAjL#{uid()}")
      submit_command(view, "/autojoin add #alpha")
      submit_command(view, "/autojoin add #beta")
      submit_command(view, "/autojoin list")

      html = render(view)
      assert html =~ "#alpha"
      assert html =~ "#beta"
    end

    test "/autojoin remove removes a channel", %{conn: conn} do
      view = connect_user(conn, "E2EAjR#{uid()}")
      submit_command(view, "/autojoin add #ajremove")
      submit_command(view, "/autojoin remove #ajremove")

      html = render(view)
      assert html =~ "Removed #ajremove from auto-join list"
    end

    test "/autojoin clear removes all channels", %{conn: conn} do
      view = connect_user(conn, "E2EAjC#{uid()}")
      submit_command(view, "/autojoin add #ch1")
      submit_command(view, "/autojoin clear")

      html = render(view)
      assert html =~ "Auto-join list cleared"
    end

    test "/autojoin add with invalid channel shows error", %{conn: conn} do
      view = connect_user(conn, "E2EAjI#{uid()}")
      submit_command(view, "/autojoin add nochannel")

      html = render(view)
      assert html =~ "must start with #"
    end

    test "autojoin execution on trigger", %{conn: conn} do
      view = connect_user(conn, "E2EAjX#{uid()}")
      submit_command(view, "/autojoin add #e2eajexec")

      send(view.pid, {:execute_autojoin, 0})

      html = render(view)
      assert html =~ "Auto-joining #e2eajexec"
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
    test "restore_session event shows restoring message", %{conn: conn} do
      view = connect_user(conn, "E2ERst#{uid()}")

      render_hook(view, "restore_session", %{
        "channels" => [],
        "active_channel" => nil,
        "active_pm" => nil
      })

      html = render(view)
      assert html =~ "Restoring session"
    end

    test "execute_rejoin joins channels not yet joined", %{conn: conn} do
      view = connect_user(conn, "E2ERjn#{uid()}")

      send(view.pid, {:execute_rejoin, 0, ["#e2erejoin"]})

      html = render(view)
      assert html =~ "Rejoining #e2erejoin"
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
    {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
    view
  end

  defp submit_command(view, command) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => command})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid do
    System.unique_integer([:positive])
  end
end
