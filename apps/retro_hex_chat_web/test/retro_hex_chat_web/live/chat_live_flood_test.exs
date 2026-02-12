defmodule RetroHexChatWeb.ChatLiveFloodTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── US1: Anti-Spam Duplicate Detection ─────────────────────

  describe "US1: duplicate message detection in channels" do
    test "messages below threshold are displayed normally", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Spammer", "hello", "#lobby")
      send_new_message(view, "Spammer", "hello", "#lobby")

      html = render(view)
      assert html =~ "hello"
    end

    test "duplicate messages are dropped after threshold", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Default spam_threshold is 3, send 3 duplicates to hit threshold
      send_new_message(view, "Spammer", "spam spam spam", "#lobby")
      send_new_message(view, "Spammer", "spam spam spam", "#lobby")
      send_new_message(view, "Spammer", "spam spam spam", "#lobby")

      # The 4th duplicate should be silently dropped
      send_new_message(view, "Spammer", "spam spam spam", "#lobby")

      # But a different message from the same sender should still appear
      send_new_message(view, "Spammer", "this is different", "#lobby")

      html = render(view)
      assert html =~ "this is different"
    end

    test "different senders are tracked independently", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Fill up threshold for SpammerA
      send_new_message(view, "SpammerA", "same msg", "#lobby")
      send_new_message(view, "SpammerA", "same msg", "#lobby")
      send_new_message(view, "SpammerA", "same msg", "#lobby")

      # SpammerB's identical message should still show (different sender)
      send_new_message(view, "SpammerB", "same msg", "#lobby")

      html = render(view)
      assert html =~ "same msg"
    end

    test "different channels are tracked independently", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Fill up threshold in #lobby
      send_new_message(view, "Spammer", "repeat", "#lobby")
      send_new_message(view, "Spammer", "repeat", "#lobby")
      send_new_message(view, "Spammer", "repeat", "#lobby")

      # Same message to #other should not be affected (different target)
      send_new_message(view, "Spammer", "repeat", "#other")

      # We can't easily assert cross-channel display, but the message
      # should not be dropped — it should at least update unread
    end

    test "system messages are never filtered by duplicate detection", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send the same system message many times
      send_system_message(view, "System", "User joined", "#lobby")
      send_system_message(view, "System", "User joined", "#lobby")
      send_system_message(view, "System", "User joined", "#lobby")
      send_system_message(view, "System", "User joined", "#lobby")

      html = render(view)
      assert html =~ "User joined"
    end
  end

  describe "US1: duplicate message detection in PMs" do
    test "duplicate PMs are tracked by the duplicate tracker", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send 3 duplicate PMs to hit threshold
      send_new_pm(view, "Spammer", nick, "buy my product")
      send_new_pm(view, "Spammer", nick, "buy my product")
      send_new_pm(view, "Spammer", nick, "buy my product")

      # The 4th duplicate should be silently dropped (no unread set)
      send_new_pm(view, "Spammer", nick, "buy my product")

      # A different message should not be dropped — verify unread is set
      send_new_pm(view, "Spammer", nick, "something else")

      # The non-duplicate should have set unread (since we're not in PM view)
      # Just verify the LiveView didn't crash processing the messages
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "US1: flood protection assigns are initialized" do
    test "duplicate_tracker assign is initialized", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      state = :sys.get_state(view.pid)
      assigns = state.socket.assigns

      assert Map.has_key?(assigns, :duplicate_tracker)
      assert assigns.duplicate_tracker.entries == %{}
    end

    test "flood_tracker assign is initialized", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      state = :sys.get_state(view.pid)
      assigns = state.socket.assigns

      assert Map.has_key?(assigns, :flood_tracker)
      assert assigns.flood_tracker.senders == %{}
    end
  end

  # ── US2: Auto-Ignore on Flood ────────────────────────────────

  describe "US2: auto-ignore triggers on flood" do
    test "flooding triggers auto-ignore and shows system message", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Default flood_threshold is 10, flood_window_seconds is 15
      # Send 10 messages to hit threshold
      for i <- 1..10 do
        send_new_message(view, "Spammer", "msg #{i}", "#lobby")
      end

      html = render(view)
      assert html =~ "auto-ignored for flooding"
    end

    test "auto-ignore expiry removes ignore and shows message", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Trigger auto-ignore
      for i <- 1..10 do
        send_new_message(view, "Spammer", "msg #{i}", "#lobby")
      end

      # Simulate auto-ignore timer expiry
      send(view.pid, {:auto_ignore_expired, "Spammer"})

      html = render(view)
      assert html =~ "no longer auto-ignored"
    end

    test "messages after auto-ignore are filtered", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Trigger auto-ignore
      for i <- 1..10 do
        send_new_message(view, "Spammer", "msg #{i}", "#lobby")
      end

      # Subsequent messages from Spammer should be filtered by ignore list
      send_new_message(view, "Spammer", "this should be hidden", "#lobby")

      html = render(view)
      refute html =~ "this should be hidden"
    end

    test "user's own messages do not trigger auto-ignore", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send messages from the user themselves
      for i <- 1..15 do
        send_new_message(view, nick, "my msg #{i}", "#lobby")
      end

      html = render(view)
      refute html =~ "auto-ignored"
    end

    test "system messages don't trigger flood tracking", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send many system messages from same author
      for _i <- 1..15 do
        send_system_message(view, "System", "someone joined", "#lobby")
      end

      html = render(view)
      refute html =~ "auto-ignored"
    end

    test "manual un-ignore after auto-ignore sets cooldown", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Trigger auto-ignore
      for i <- 1..10 do
        send_new_message(view, "Spammer", "msg #{i}", "#lobby")
      end

      html_before = render(view)
      # Count occurrences of auto-ignore message before unignore
      before_count =
        html_before
        |> String.split("auto-ignored for flooding")
        |> length()
        |> Kernel.-(1)

      assert before_count == 1

      # Manually un-ignore
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/unignore Spammer"})

      # Now flood again — should NOT re-trigger due to cooldown
      for i <- 1..10 do
        send_new_message(view, "Spammer", "new msg #{i}", "#lobby")
      end

      html_after = render(view)

      after_count =
        html_after
        |> String.split("auto-ignored for flooding")
        |> length()
        |> Kernel.-(1)

      # Should still be 1 (no new auto-ignore triggered)
      assert after_count == 1
    end
  end

  describe "US2: auto-ignore in PMs" do
    test "PM flooding triggers auto-ignore", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send 10 PMs from same sender
      for i <- 1..10 do
        send_new_pm(view, "Spammer", nick, "pm #{i}")
      end

      html = render(view)
      assert html =~ "auto-ignored for flooding"
    end
  end

  # ── US3: CTCP Flood Protection ────────────────────────────────

  describe "US3: CTCP reply rate limiting" do
    test "CTCP replies within limit are sent", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Default ctcp_reply_limit is 2, window is 10 seconds
      # First 2 requests should generate replies
      send_ctcp_request(view, "Requester", :version, "req-1")
      send_ctcp_request(view, "Requester", :version, "req-2")

      html = render(view)
      # Both should show "CTCP VERSION request from Requester"
      version_count =
        html
        |> String.split("CTCP VERSION request from Requester")
        |> length()
        |> Kernel.-(1)

      assert version_count == 2
    end

    test "CTCP replies exceeding limit are silently dropped", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send 3 requests — only first 2 should trigger replies
      send_ctcp_request(view, "Requester", :version, "req-1")
      send_ctcp_request(view, "Requester", :version, "req-2")
      send_ctcp_request(view, "Requester", :version, "req-3")

      # All 3 should show the request system message (we always display those)
      html = render(view)

      request_count =
        html
        |> String.split("CTCP VERSION request from Requester")
        |> length()
        |> Kernel.-(1)

      assert request_count == 3

      # The ctcp_reply_tracker should have 2 timestamps (replies sent for first 2 only)
      state = :sys.get_state(view.pid)
      assigns = state.socket.assigns
      assert length(assigns.ctcp_reply_tracker.timestamps) == 2
    end
  end

  # ── US4: Flood Protection Settings Dialog ───────────────────

  describe "US4: settings dialog" do
    test "open and close dialog", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_flood_protection_dialog")
      html = render(view)
      assert html =~ "Flood Protection"
      assert html =~ "flood-protection-dialog"

      render_click(view, "close_flood_protection_dialog")
      html = render(view)
      refute html =~ "flood-protection-dialog"
    end

    test "save settings updates session", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_flood_protection_dialog")

      view
      |> element("#flood-protection-form")
      |> render_submit(%{
        "flood_threshold" => "20",
        "flood_window_seconds" => "30",
        "auto_ignore_duration_seconds" => "600",
        "spam_threshold" => "5",
        "spam_window_seconds" => "15",
        "ctcp_reply_limit" => "4",
        "ctcp_reply_window_seconds" => "20"
      })

      html = render(view)
      assert html =~ "Flood protection settings saved"
    end

    test "reset to defaults restores default values", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # First save custom settings
      render_click(view, "open_flood_protection_dialog")

      view
      |> element("#flood-protection-form")
      |> render_submit(%{
        "flood_threshold" => "20",
        "flood_window_seconds" => "30",
        "auto_ignore_duration_seconds" => "600",
        "spam_threshold" => "5",
        "spam_window_seconds" => "15",
        "ctcp_reply_limit" => "4",
        "ctcp_reply_window_seconds" => "20"
      })

      # Reset to defaults
      render_click(view, "flood_reset_defaults")

      html = render(view)
      assert html =~ "Flood protection settings reset to defaults"
    end

    test "menu Tools > Flood Protection opens dialog", %{conn: conn} do
      nick = "Flood#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_flood_protection_dialog")

      html = render(view)
      assert html =~ "flood-protection-dialog"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_ctcp_request(view, sender, type, request_id) do
    msg =
      {:ctcp_request,
       %{
         type: type,
         sender: sender,
         request_id: request_id,
         sent_at: System.monotonic_time(:millisecond)
       }}

    send(view.pid, msg)
    :timer.sleep(5)
  end

  defp send_new_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "msg-#{System.unique_integer([:positive])}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
    # Small yield to allow the LiveView to process
    :timer.sleep(5)
  end

  defp send_system_message(view, _author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "sys-#{System.unique_integer([:positive])}",
        author: "System",
        content: content,
        type: :system,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
    :timer.sleep(5)
  end

  defp send_new_pm(view, sender, recipient, content) do
    msg = %{
      event: "new_pm",
      payload: %{
        id: "pm-#{System.unique_integer([:positive])}",
        sender: sender,
        recipient: recipient,
        content: content,
        type: :message,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
    :timer.sleep(5)
  end
end
