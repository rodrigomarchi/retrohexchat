defmodule RetroHexChatWeb.ChatLive.MultiSessionTest do
  @moduledoc """
  One nickname, more than one screen.

  Opening the chat used to end whatever chat the person already had, so the
  desktop died when the phone woke up. It no longer does, and everything
  asserted here is something that only breaks once two screens are allowed: the
  membership they share, the presence they share, and the place in the
  conversation they should share.

  The absence assertions are the point of the file. Closing one screen must not
  take the other out of the channel and must not announce that the person went
  offline — those are the two bugs this change can introduce, and both were seen
  failing before the code that prevents them existed.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.ReconnectState
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Topics

  setup ctx do
    nick = "Multi#{uid()}"
    other = "Other#{uid()}"
    {:ok, _} = register(nick)
    {:ok, _} = register(other)
    channel = "#multi#{uid()}"

    desktop = open_chat(ctx.conn, nick, "browser-desktop")
    submit_command_sync(desktop, "/join #{channel}")
    {:ok, _} = Server.join(channel, other)

    %{nick: nick, other: other, channel: channel, desktop: desktop}
  end

  describe "two screens at once" do
    test "the second screen does not end the first", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")

      assert Process.alive?(ctx.desktop.pid)
      assert Process.alive?(phone.pid)
    end

    test "both screens are in the channel, as one member", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      render_click(phone, "switch_channel", %{"channel" => ctx.channel})

      {:ok, state} = Server.get_state(ctx.channel)
      members = Enum.map(state.members, fn {member, _role} -> member end)

      assert ctx.nick in members
      assert Enum.count(members, &(&1 == ctx.nick)) == 1
    end

    # One delivery per screen, asserted where it is decided rather than in the
    # rendered stream: a stream row arrives through `send_update`, and asserting
    # on that is how this suite has been made flaky before. A duplicate line
    # would come from one socket holding two subscriptions, and that is a fact
    # the registry answers synchronously.
    test "each screen is subscribed to the channel exactly once", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      submit_command_sync(phone, "/join #{ctx.channel}")

      subscribers = Registry.lookup(RetroHexChat.PubSub, "channel:#{ctx.channel}")

      assert Enum.count(subscribers, fn {pid, _value} -> pid == ctx.desktop.pid end) == 1
      assert Enum.count(subscribers, fn {pid, _value} -> pid == phone.pid end) == 1
    end

    test "each screen keeps its own reconnect snapshot", ctx do
      elsewhere = "#else#{uid()}"
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      submit_command_sync(phone, "/join #{elsewhere}")

      assert {:ok, desk_snapshot} = ReconnectState.load(ctx.nick, "browser-desktop")
      assert {:ok, phone_snapshot} = ReconnectState.load(ctx.nick, "browser-phone")

      assert ctx.channel in desk_snapshot.channels
      refute elsewhere in desk_snapshot.channels
      assert elsewhere in phone_snapshot.channels
    end
  end

  describe "closing one screen" do
    # The bug this whole change can introduce: a membership is per nickname, so
    # one window leaving would take the other out of a conversation it is still
    # showing.
    test "does not take the other screen out of the channel", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      render_click(phone, "switch_channel", %{"channel" => ctx.channel})

      close(ctx.desktop)

      {:ok, state} = Server.get_state(ctx.channel)
      assert Enum.any?(state.members, fn {member, _role} -> member == ctx.nick end)
    end

    test "does not announce that the person went offline", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      :ok = Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.presence())

      close(ctx.desktop)

      refute_receive {:user_disconnected, %{nickname: _}}, 300
      assert Process.alive?(phone.pid)
    end

    test "announces it once the last screen goes", ctx do
      :ok = Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.presence())

      close(ctx.desktop)

      assert_receive {:user_disconnected, %{nickname: nickname}}, 500
      assert nickname == ctx.nick
    end
  end

  describe "the screen that gives way to the ceiling" do
    # Being evicted by the ceiling is not being signed out. That browser is one
    # the person will come back to, and the whole point of the snapshot is that
    # coming back does not start from nothing. A ban is the opposite and still
    # clears it.
    test "keeps the snapshot of its own browser", ctx do
      assert {:ok, _snapshot} = ReconnectState.load(ctx.nick, "browser-desktop")

      send(
        ctx.desktop.pid,
        {:force_disconnect,
         %{
           reason: "made room",
           skip_channel_cleanup: true,
           skip_whowas: true,
           keep_reconnect_state: true
         }}
      )

      assert_redirect(ctx.desktop, 5_000)
      assert {:ok, snapshot} = ReconnectState.load(ctx.nick, "browser-desktop")
      assert ctx.channel in snapshot.channels
    end

    test "a disconnect that is not the ceiling still clears it", ctx do
      assert {:ok, _snapshot} = ReconnectState.load(ctx.nick, "browser-desktop")

      send(ctx.desktop.pid, {:force_disconnect, %{reason: "banned"}})

      assert_redirect(ctx.desktop, 5_000)
      assert {:error, :not_found} = ReconnectState.load(ctx.nick, "browser-desktop")
    end
  end

  describe "where you had got to follows you" do
    test "reading on one screen clears the unread count on the other", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      submit_command_sync(phone, "/join #{ctx.channel}")

      # Both have the channel open; the desktop looks away so the channel is a
      # background conversation for it and starts counting.
      elsewhere = "#else#{uid()}"
      submit_command_sync(ctx.desktop, "/join #{elsewhere}")
      {:ok, _} = Server.send_message(ctx.channel, ctx.other, "something new")

      assert unread(ctx.desktop)[ctx.channel]

      # The phone reads it and looks away, which is what moves a marker. The
      # broadcast lands in the desktop's mailbox before `render_click` returns,
      # so the `:sys.get_state` below is queued behind it and needs no waiting.
      render_click(phone, "tab_focused", %{})

      refute unread(ctx.desktop)[ctx.channel]
    end

    test "a marker only ever moves forward on the other screen", ctx do
      phone = open_chat(build_conn(), ctx.nick, "browser-phone")
      submit_command_sync(phone, "/join #{ctx.channel}")

      {:ok, newer} = Server.send_message(ctx.channel, ctx.other, "the newer line")
      render_click(phone, "tab_focused", %{})
      assert markers(ctx.desktop)[ctx.channel] == newer

      # An older marker arriving late must not drag the reader backwards.
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        Topics.inbox(ctx.nick),
        {:read_marker_advanced, %{key: ctx.channel, message_id: newer - 1}}
      )

      assert markers(ctx.desktop)[ctx.channel] == newer
    end
  end

  # Identified, because an unidentified session deliberately writes no snapshot
  # at all — the reconnect state belongs to a registered owner.
  defp open_chat(conn, nickname, browser_id) do
    {:ok, view, _html} =
      conn
      |> chat_conn(nickname, browser_id: browser_id, pre_identified: true)
      |> live(~p"/chat")

    view
  end

  defp close(view) do
    ref = Process.monitor(view.pid)
    GenServer.stop(view.pid, :normal)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 1_000
  end

  defp unread(view), do: :sys.get_state(view.pid).socket.assigns.unread_counts
  defp markers(view), do: :sys.get_state(view.pid).socket.assigns.read_markers

  # Registered *and* identified: a session that has not identified deliberately
  # writes no reconnect snapshot, so half of what this file asserts would be
  # vacuous without it.
  defp register(nickname) do
    NickServ.register(nickname, "password123")
    NickServ.identify(nickname, "password123")
  end
end
