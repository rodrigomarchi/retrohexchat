defmodule RetroHexChatWeb.ChatLiveInviteTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── Helpers ──────────────────────────────────────────────

  defp unique_nick(prefix) do
    "#{prefix}#{System.unique_integer([:positive])}"
  end

  defp unique_channel do
    "#inv#{System.unique_integer([:positive])}"
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")
    view
  end

  defp send_command(view, command) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => command})
  end

  defp setup_invite_channel(op_view, channel) do
    send_command(op_view, "/join #{channel}")
    send_command(op_view, "/mode +i")
  end

  # ── US1: Operator sends invite ───────────────────────────

  describe "/invite command — operator sends invite" do
    test "/invite with no args shows usage error", %{conn: conn} do
      nick = unique_nick("InvCmd")
      view = connect_user(conn, nick)
      send_command(view, "/invite")

      html = render(view)
      assert html =~ "Usage: /invite"
    end

    test "/invite auto toggles auto-join preference", %{conn: conn} do
      nick = unique_nick("InvAut")
      view = connect_user(conn, nick)

      send_command(view, "/invite auto")
      html = render(view)
      assert html =~ "Auto-join on invite: enabled"

      send_command(view, "/invite auto")
      html = render(view)
      assert html =~ "Auto-join on invite: disabled"
    end

    test "/invite nickname sends invite and shows confirmation", %{conn: conn} do
      operator = unique_nick("InvOp")
      target = unique_nick("InvTgt")
      channel = unique_channel()

      op_view = connect_user(conn, operator)
      _tgt_view = connect_user(conn, target)

      setup_invite_channel(op_view, channel)
      send_command(op_view, "/invite #{target} #{channel}")

      html = render(op_view)
      assert html =~ "Inviting #{target} to #{channel}"
    end

    test "/invite to non-invite-only channel shows error", %{conn: conn} do
      operator = unique_nick("InvNI")
      target = unique_nick("InvNIT")
      channel = unique_channel()

      op_view = connect_user(conn, operator)
      _tgt_view = connect_user(conn, target)

      send_command(op_view, "/join #{channel}")
      # Don't set +i — channel is open
      send_command(op_view, "/invite #{target} #{channel}")

      html = render(op_view)
      assert html =~ "not invite-only"
    end

    test "/invite non-existent user shows error", %{conn: conn} do
      operator = unique_nick("InvNE")
      channel = unique_channel()

      op_view = connect_user(conn, operator)
      setup_invite_channel(op_view, channel)
      send_command(op_view, "/invite NonExistentUser99999 #{channel}")

      html = render(op_view)
      assert html =~ "not found"
    end
  end

  # ── US2: Invitee receives dialog and joins ───────────────

  describe "invite dialog — receive and respond" do
    test "receiving invite shows dialog with inviter and channel", %{conn: conn} do
      target = unique_nick("DlgTgt")
      channel = unique_channel()

      tgt_view = connect_user(conn, target)

      # Directly send invite message (simulates PubSub delivery)
      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "SomeOperator"}})
      Process.sleep(50)

      html = render(tgt_view)
      assert html =~ "Channel Invitation"
      assert html =~ "SomeOperator"
      assert html =~ channel
      assert html =~ "Join"
      assert html =~ "Ignore"
    end

    test "clicking Ignore dismisses dialog without joining", %{conn: conn} do
      target = unique_nick("IgTgt")
      channel = unique_channel()

      tgt_view = connect_user(conn, target)

      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "SomeOp"}})
      Process.sleep(50)

      # Click Ignore (use text selector to avoid matching Close button in title bar)
      tgt_view |> element(".window-body button[phx-click=invite_ignore]") |> render_click()

      html = render(tgt_view)
      refute html =~ "Channel Invitation"
    end

    test "multiple invites show cascading dialogs", %{conn: conn} do
      target = unique_nick("CscTgt")
      ch1 = unique_channel()
      ch2 = unique_channel()

      tgt_view = connect_user(conn, target)

      send(tgt_view.pid, {:channel_invite, %{channel: ch1, inviter: "Op1"}})
      send(tgt_view.pid, {:channel_invite, %{channel: ch2, inviter: "Op2"}})
      Process.sleep(50)

      html = render(tgt_view)
      assert html =~ ch1
      assert html =~ ch2
      # Both dialogs should appear
      matches = Regex.scan(~r/Channel Invitation/, html)
      assert length(matches) == 2
    end

    test "clicking Join on invite joins the channel via full flow", %{conn: conn} do
      operator = unique_nick("JnOp")
      target = unique_nick("JnTgt")
      channel = unique_channel()

      op_view = connect_user(conn, operator)
      tgt_view = connect_user(conn, target)

      setup_invite_channel(op_view, channel)
      send_command(op_view, "/invite #{target} #{channel}")

      Process.sleep(100)

      # Click Join
      tgt_view |> element("button[phx-click=invite_accept]") |> render_click()

      html = render(tgt_view)
      # Dialog should be gone
      refute html =~ "Channel Invitation"
      # Channel should appear in treebar
      assert html =~ channel
    end
  end

  # ── US3: Invite expiration ──────────────────────────────

  describe "invite expiration" do
    test "expired invite is removed from pending list", %{conn: conn} do
      target = unique_nick("ExpTgt")
      channel = unique_channel()

      tgt_view = connect_user(conn, target)

      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "SomeOp"}})
      Process.sleep(50)

      html = render(tgt_view)
      assert html =~ "Channel Invitation"

      # Simulate expiration
      send(tgt_view.pid, {:invite_expired, channel})
      Process.sleep(50)

      html = render(tgt_view)
      refute html =~ "Channel Invitation"
    end

    test "accepting after expiration shows expired error", %{conn: conn} do
      target = unique_nick("ExpAcc")
      channel = unique_channel()

      tgt_view = connect_user(conn, target)

      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "SomeOp"}})
      Process.sleep(50)

      # Expire the invite
      send(tgt_view.pid, {:invite_expired, channel})
      Process.sleep(50)

      # Try to accept the now-expired invite directly
      render_click(tgt_view, "invite_accept", %{"channel" => channel})

      html = render(tgt_view)
      assert html =~ "expired"
    end

    test "duplicate invite to same channel replaces existing", %{conn: conn} do
      target = unique_nick("DupTgt")
      channel = unique_channel()

      tgt_view = connect_user(conn, target)

      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "Op1"}})
      Process.sleep(50)

      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "Op2"}})
      Process.sleep(50)

      html = render(tgt_view)
      # Should show latest inviter
      assert html =~ "Op2"
      # Should still be just one dialog
      assert length(Regex.scan(~r/Channel Invitation/, html)) == 1
    end
  end

  # ── US4: Auto-join on invite ────────────────────────────

  describe "auto-join on invite" do
    test "auto-join enabled skips dialog and joins immediately", %{conn: conn} do
      operator = unique_nick("AjOp")
      target = unique_nick("AjTgt")
      channel = unique_channel()

      op_view = connect_user(conn, operator)
      tgt_view = connect_user(conn, target)

      # Enable auto-join
      send_command(tgt_view, "/invite auto")

      setup_invite_channel(op_view, channel)
      send_command(op_view, "/invite #{target} #{channel}")

      Process.sleep(100)

      html = render(tgt_view)
      # No dialog should appear
      refute html =~ "Channel Invitation"
      # Should see auto-joined message
      assert html =~ "auto-joined"
    end

    test "auto-join disabled shows dialog (default behavior)", %{conn: conn} do
      target = unique_nick("NoAjTgt")
      channel = unique_channel()

      tgt_view = connect_user(conn, target)

      send(tgt_view.pid, {:channel_invite, %{channel: channel, inviter: "SomeOp"}})
      Process.sleep(50)

      html = render(tgt_view)
      assert html =~ "Channel Invitation"
    end
  end
end
