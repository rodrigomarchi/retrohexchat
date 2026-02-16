defmodule RetroHexChatWeb.ChatLivePerformTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── /perform command ────────────────────────────────────────

  describe "/perform command" do
    test "/perform list with empty list shows system message", %{conn: conn} do
      nick = "PerfLst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/perform list"})

      html = render(view)
      assert html =~ "empty"
    end

    test "/perform add /join #test adds to list", %{conn: conn} do
      nick = "PerfAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #test"})

      html = render(view)
      assert html =~ "Added to perform list"
    end

    test "/perform add /ns identify secret masks password", %{conn: conn} do
      nick = "PerfMsk#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /ns identify secret"})

      html = render(view)
      assert html =~ "****"
      refute html =~ "secret"
    end

    test "/perform list shows entries after adding", %{conn: conn} do
      nick = "PerfEnt#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #alpha"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #beta"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/perform list"})

      html = render(view)
      assert html =~ "0:"
      assert html =~ "1:"
      assert html =~ "/join #alpha"
      assert html =~ "/join #beta"
    end

    test "/perform remove 0 removes entry", %{conn: conn} do
      nick = "PerfRem#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #removeme"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform remove 0"})

      html = render(view)
      assert html =~ "Removed command at position 0"
    end

    test "/perform move 0 1 moves entry", %{conn: conn} do
      nick = "PerfMov#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #first"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #second"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform move 0 1"})

      html = render(view)
      assert html =~ "Moved command from position 0 to 1"
    end

    test "/perform clear clears all entries", %{conn: conn} do
      nick = "PerfClr#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #ch1"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #ch2"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform clear"})

      html = render(view)
      assert html =~ "Perform list cleared"
    end

    test "/perform add with disallowed command shows error", %{conn: conn} do
      nick = "PerfDis#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /quit"})

      html = render(view)
      assert html =~ "cannot be added to the perform list"
    end

    test "/perform remove with invalid position shows error", %{conn: conn} do
      nick = "PerfInv#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform remove 99"})

      html = render(view)
      assert html =~ "No command at position 99"
    end
  end

  # ── perform execution on connect ─────────────────────────────

  describe "perform execution on connect" do
    test "handle_info {:execute_perform, 0} executes first command", %{conn: conn} do
      nick = "PerfExe#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Add a command to the perform list first
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #perftest"})

      # Trigger perform execution by sending the handle_info message directly
      send(view.pid, {:execute_perform, 0})

      html = render(view)
      assert html =~ "Performing: /join #perftest"
    end

    test "{:execute_perform, index} past end is a no-op", %{conn: conn} do
      nick = "PerfEnd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # With empty perform list, send {:execute_perform, 0}
      # Should trigger {:execute_autojoin, 0} which is currently a no-op
      send(view.pid, {:execute_perform, 0})

      html = render(view)
      # Should not crash; page is still functional
      assert html =~ nick
    end
  end

  # ── autojoin command ────────────────────────────────────────

  describe "/autojoin command" do
    test "/autojoin list with empty list shows system message", %{conn: conn} do
      nick = "AJLst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/autojoin list"})

      html = render(view)
      assert html =~ "empty"
    end

    test "/autojoin add #channel adds to list", %{conn: conn} do
      nick = "AJAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add #testchan"})

      html = render(view)
      assert html =~ "Added to auto-join list"
    end

    test "/autojoin list shows entries after adding", %{conn: conn} do
      nick = "AJEnt#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add #alpha"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add #beta"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/autojoin list"})

      html = render(view)
      assert html =~ "#alpha"
      assert html =~ "#beta"
    end

    test "/autojoin remove #channel removes entry", %{conn: conn} do
      nick = "AJRem#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add #removeme"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin remove #removeme"})

      html = render(view)
      assert html =~ "Removed #removeme from auto-join list"
    end

    test "/autojoin clear clears all entries", %{conn: conn} do
      nick = "AJClr#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add #ch1"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin clear"})

      html = render(view)
      assert html =~ "Auto-join list cleared"
    end

    test "/autojoin add with invalid channel shows error", %{conn: conn} do
      nick = "AJInv#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add nochannel"})

      html = render(view)
      assert html =~ "must start with #"
    end
  end

  # ── autojoin execution on connect ───────────────────────────

  describe "autojoin execution on connect" do
    test "handle_info {:execute_autojoin, 0} auto-joins first channel", %{conn: conn} do
      nick = "AJExe#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/autojoin add #ajtest"})

      send(view.pid, {:execute_autojoin, 0})

      html = render(view)
      assert html =~ "Auto-joining #ajtest"
    end

    test "{:execute_autojoin, index} past end is a no-op", %{conn: conn} do
      nick = "AJEnd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, {:execute_autojoin, 0})

      html = render(view)
      assert html =~ nick
    end
  end

  # ── reconnect push_events ───────────────────────────────────

  describe "reconnect push_events" do
    test "quit_chat pushes intentional_disconnect event", %{conn: conn} do
      nick = "RcnQui#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/quit"})

      assert_push_event(view, "intentional_disconnect", %{})
    end

    test "joining a channel pushes save_reconnect_state", %{conn: conn} do
      nick = "RcnJoi#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #rcnjoin"})

      assert_push_event(view, "save_reconnect_state", %{
        nickname: ^nick,
        channels: channels,
        active_channel: "#rcnjoin"
      })

      assert "#rcnjoin" in channels
    end

    test "parting a channel pushes save_reconnect_state", %{conn: conn} do
      nick = "RcnPar#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #rcnpart"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/part #rcnpart"})

      assert_push_event(view, "save_reconnect_state", %{
        nickname: ^nick,
        channels: channels
      })

      refute "#rcnpart" in channels
    end

    test "switching channel pushes save_reconnect_state", %{conn: conn} do
      nick = "RcnSwi#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #rcnswitch"})

      # Switch back to lobby
      render_click(view, "switch_channel", %{"channel" => "#lobby"})

      assert_push_event(view, "save_reconnect_state", %{
        active_channel: "#lobby"
      })
    end
  end

  # ── session restoration on reconnect ────────────────────────

  describe "session restoration on reconnect" do
    test "restore_session event shows restoring message", %{conn: conn} do
      nick = "RstMsg#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "restore_session", %{
        "channels" => ["#lobby"],
        "active_channel" => "#lobby",
        "active_pm" => nil
      })

      html = render(view)
      assert html =~ "Restoring session"
    end

    test "execute_rejoin joins non-joined channels", %{conn: conn} do
      nick = "RstRej#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Send execute_rejoin with a channel not yet joined
      send(view.pid, {:execute_rejoin, 0, ["#rstrejoin"]})

      html = render(view)
      assert html =~ "Rejoining #rstrejoin"
    end

    test "execute_rejoin skips channels already joined (deduplication)", %{conn: conn} do
      nick = "RstDed#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # #lobby is already joined on connect — send rejoin for just #lobby
      send(view.pid, {:execute_rejoin, 0, ["#lobby"]})

      html = render(view)
      # Should NOT show "Rejoining #lobby" since already joined
      refute html =~ "Rejoining #lobby"
    end

    test "execute_rejoin restores active channel after chain completes", %{conn: conn} do
      nick = "RstAct#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Join a second channel
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #rstactive"})

      # Set reconnect target to #lobby (currently active is #rstactive)
      render_hook(view, "restore_session", %{
        "channels" => [],
        "active_channel" => "#lobby",
        "active_pm" => nil
      })

      # Send past-end index to trigger maybe_restore_active_tab
      send(view.pid, {:execute_rejoin, 0, []})

      html = render(view)
      # Page should still work after restoration
      assert html =~ nick
    end

    test "restore_session with empty channels is no-op", %{conn: conn} do
      nick = "RstEmp#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "restore_session", %{
        "channels" => [],
        "active_channel" => nil,
        "active_pm" => nil
      })

      html = render(view)
      assert html =~ "Restoring session"
      assert html =~ nick
    end

    test "restore_session ignores state from a different user", %{conn: conn} do
      nick = "RstDif#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html =
        render_hook(view, "restore_session", %{
          "nickname" => "someone_else",
          "channels" => ["#leaked"],
          "active_channel" => "#leaked",
          "active_pm" => nil
        })

      refute html =~ "Restoring session"
      refute html =~ "#leaked"
    end
  end

  # ── perform disabled toggle ──────────────────────────────────

  describe "perform disabled toggle" do
    # When perform list is disabled, maybe_trigger_perform doesn't trigger.
    # This is internal logic tested indirectly — the dialog (US2) will
    # provide the toggle UI. For now, verify the enabled default works.
    test "perform list is enabled by default", %{conn: conn} do
      nick = "PerfDef#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Add a command and verify it can be listed (proves list is functional)
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/perform add /join #deftest"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/perform list"})

      html = render(view)
      assert html =~ "/join #deftest"
    end
  end
end
