defmodule RetroHexChat.SurfacesTest do
  @moduledoc """
  Who still has this product open, and what that decides.

  A person used to have exactly one process: the chat's LiveView. Closing its
  tab meant they were gone, and parting them from every channel there was the
  right thing to do. A call in a tab of its own breaks that equivalence — the
  chat can close while the person is still very much here, in a room whose
  policy asks, every time, whether they are a member of the channel.

  What is asserted here is the rule that replaces it: the channels are left
  when the *last* surface closes, and never before.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Surfaces

  @moduletag :integration

  defp unique_nick(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

  defp open_channel(name) do
    {:ok, pid} = ChannelSupervisor.start_child(name)

    on_exit(fn ->
      if Process.alive?(pid), do: ChannelSupervisor.stop_child(ChannelSupervisor, pid)
    end)

    name
  end

  # A surface is a process, so a fake one is a process. It reports back when it
  # has registered, so the test never races the monitor.
  defp start_surface(nickname, kind, path \\ nil) do
    test = self()

    pid =
      spawn(fn ->
        :ok = Surfaces.open(nickname, kind)
        if path, do: :ok = Surfaces.address(nickname, path)
        send(test, {:registered, self()})

        receive do
          {:move, to} ->
            :ok = Surfaces.address(nickname, to)
            send(test, {:moved, self()})

            receive do
              :close -> :ok
              :crash -> exit(:boom)
            end

          :release ->
            :ok = Surfaces.release(nickname)
            send(test, {:released, self()})

            receive do
              :close -> :ok
              :crash -> exit(:boom)
            end

          :close ->
            :ok

          :crash ->
            exit(:boom)
        end
      end)

    assert_receive {:registered, ^pid}, 1_000
    pid
  end

  defp release(pid) do
    send(pid, :release)
    assert_receive {:released, ^pid}, 1_000
    :ok
  end

  defp move(pid, path) do
    send(pid, {:move, path})
    assert_receive {:moved, ^pid}, 1_000
    :ok
  end

  defp close(pid) do
    ref = Process.monitor(pid)
    send(pid, :close)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1_000
    :ok
  end

  defp crash(pid) do
    ref = Process.monitor(pid)
    send(pid, :crash)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1_000
    :ok
  end

  # An empty channel shuts its server down, so "gone" is one of the shapes
  # "nobody is in it" takes.
  defp members(channel) do
    case Server.get_state(channel) do
      {:ok, state} -> Enum.map(state.members, fn {nick, _role} -> nick end)
      {:error, _absent} -> []
    end
  end

  # Counting answered "may the channels be left yet". This answers the other
  # half: the chat has to draw the difference between opening a call and going
  # back to the one that is already open, and that difference is an address.
  describe "what is open, not just how many" do
    test "a surface says where it is, and can say it again when it moves" do
      nickname = unique_nick("addr")
      play = start_surface(nickname, RetroHexChatWeb.App.PlayLive, "/play")

      assert [%{kind: RetroHexChatWeb.App.PlayLive, path: "/play"}] = Surfaces.list(nickname)
      assert Surfaces.open?(nickname, "/play")
      refute Surfaces.open?(nickname, "/play/hex_pong")

      move(play, "/play/hex_pong")

      assert Surfaces.open?(nickname, "/play/hex_pong")
      refute Surfaces.open?(nickname, "/play")

      close(play)
      assert Surfaces.list(nickname) == []
    end

    # Two calls are two rooms. Answering "is a call open" instead of "is *this*
    # call open" is how a person would be sent back to somebody else's room.
    test "two surfaces of the same kind are told apart by their address" do
      nickname = unique_nick("addr")
      one = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/one")
      _two = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/two")

      assert Surfaces.open?(nickname, "/call/one")
      assert Surfaces.open?(nickname, "/call/two")
      refute Surfaces.open?(nickname, "/call/three")

      close(one)

      refute Surfaces.open?(nickname, "/call/one")
      assert Surfaces.open?(nickname, "/call/two")
    end

    test "a surface that never said where it is has no address to match" do
      nickname = unique_nick("addr")
      start_surface(nickname, RetroHexChatWeb.App.CallLive)

      assert [%{path: nil}] = Surfaces.list(nickname)
      refute Surfaces.open?(nickname, "/call/one")
    end

    # A conference somebody has left still has a tab and still counts for the
    # membership rule, but sending anyone to it would land them on a page that
    # says only that it is finished.
    test "a finished surface gives up its address without giving up its tab" do
      nickname = unique_nick("addr")
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/one")

      assert Surfaces.open?(nickname, "/call/one")
      assert Surfaces.count(nickname) == 1

      release(call)

      refute Surfaces.open?(nickname, "/call/one")
      assert Surfaces.count(nickname) == 1
      assert [%{path: nil}] = Surfaces.list(nickname)
    end

    test "the address of somebody else's surface is not this person's" do
      mine = unique_nick("addra")
      theirs = unique_nick("addrb")
      start_surface(theirs, RetroHexChatWeb.App.CallLive, "/call/one")

      refute Surfaces.open?(mine, "/call/one")
    end
  end

  # The chat cannot poll: it has to be told, and it has to be told on a topic
  # that carries nothing else.
  describe "announcing the set" do
    setup do
      nickname = unique_nick("Announce")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Surfaces.topic(nickname))
      %{nickname: nickname}
    end

    test "opening, moving and closing each announce the whole set", %{nickname: nickname} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/one")

      assert_receive {:surfaces_changed, [%{path: nil}]}, 1_000
      assert_receive {:surfaces_changed, [%{path: "/call/one"}]}, 1_000

      move(call, "/call/two")
      assert_receive {:surfaces_changed, [%{path: "/call/two"}]}, 1_000

      close(call)
      assert_receive {:surfaces_changed, []}, 1_000
    end

    test "a crash announces exactly like a close", %{nickname: nickname} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/one")
      assert_receive {:surfaces_changed, [%{path: "/call/one"}]}, 1_000

      crash(call)
      assert_receive {:surfaces_changed, []}, 1_000
    end

    # The registry keys people by their downcased nickname. A subscriber that
    # built the topic from the cased form would listen to silence, and only for
    # the people whose nickname has a capital in it.
    test "the topic is the same whichever case the nickname is written in", %{
      nickname: nickname
    } do
      assert Surfaces.topic(nickname) == Surfaces.topic(String.downcase(nickname))

      start_surface(String.downcase(nickname), RetroHexChatWeb.App.CallLive, "/call/one")
      assert_receive {:surfaces_changed, [%{path: "/call/one"}]}, 1_000
    end

    test "saying the same address twice announces once", %{nickname: nickname} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/one")
      assert_receive {:surfaces_changed, [%{path: nil}]}, 1_000
      assert_receive {:surfaces_changed, [%{path: "/call/one"}]}, 1_000

      move(call, "/call/one")
      refute_receive {:surfaces_changed, _set}, 200
    end
  end

  describe "counting what is open" do
    test "a person with no surfaces has none" do
      assert Surfaces.count(unique_nick("none")) == 0
    end

    test "the chat and a call are two surfaces, and closing one leaves one" do
      nickname = unique_nick("two")
      chat = start_surface(nickname, RetroHexChatWeb.App.ChatLive)
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive)

      assert Surfaces.count(nickname) == 2

      close(call)
      assert Surfaces.count(nickname) == 1

      close(chat)
      assert Surfaces.count(nickname) == 0
    end

    # `terminate/2` does not run on every path a process leaves by, which is
    # why this is a monitor and not a callback.
    test "a surface that crashes is counted out too" do
      nickname = unique_nick("crash")
      pid = start_surface(nickname, RetroHexChatWeb.App.CallLive)

      assert Surfaces.count(nickname) == 1
      crash(pid)
      assert Surfaces.count(nickname) == 0
    end

    test "nicknames are counted the way the server compares them" do
      nickname = unique_nick("Case")
      pid = start_surface(nickname, RetroHexChatWeb.App.ChatLive)

      assert Surfaces.count(String.upcase(nickname)) == 1
      close(pid)
    end
  end

  describe "the departure the chat hands over" do
    setup do
      nickname = unique_nick("dep")
      channel = open_channel("#surf#{System.unique_integer([:positive])}")
      {:ok, _state} = Server.join(channel, nickname, nil, identified: true)

      %{nickname: nickname, channel: channel}
    end

    # The bug this whole mechanism exists for: the chat's tab closing must not
    # take the person out of the channels a call still stands on.
    test "runs only when the last surface goes", %{nickname: nickname, channel: channel} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive)

      Surfaces.defer_part(nickname, [channel], "Connection lost")
      assert nickname in members(channel)

      close(call)

      assert_eventually(fn -> nickname not in members(channel) end)
    end

    test "runs after a crash of the last surface", %{nickname: nickname, channel: channel} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive)
      Surfaces.defer_part(nickname, [channel], "Connection lost")

      crash(call)

      assert_eventually(fn -> nickname not in members(channel) end)
    end

    # A chat that comes back owns the lifetime again: the handover it left
    # behind must not fire under it later.
    test "is cancelled when a chat comes back", %{nickname: nickname, channel: channel} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive)
      Surfaces.defer_part(nickname, [channel], "Connection lost")

      chat = start_surface(nickname, RetroHexChatWeb.App.ChatLive)
      Surfaces.cancel_deferred(nickname)

      close(call)
      close(chat)

      assert nickname in members(channel)
    end

    test "does nothing when nobody handed one over", %{nickname: nickname, channel: channel} do
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive)
      close(call)

      assert nickname in members(channel)
    end

    # A rename moves the person, and the departure handed over before it has to
    # part the channels of the name the channels now know.
    test "follows a rename", %{nickname: nickname, channel: channel} do
      renamed = unique_nick("dep")
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive)

      Surfaces.defer_part(nickname, [channel], "Connection lost")
      :ok = Server.rename_user(channel, nickname, renamed)
      :ok = Surfaces.rename(nickname, renamed)

      close(call)

      assert_eventually(fn -> renamed not in members(channel) end)
    end
  end

  # A nick change moves presence, the inbox and the channel memberships. This
  # is the fourth thing it moves, and the one whose absence is silent: a tab
  # left registered under the old name is a tab nothing counts.
  describe "following a rename" do
    test "the tabs answer to the new name and the old one has none" do
      old = unique_nick("ren")
      new = unique_nick("ren")
      call = start_surface(old, RetroHexChatWeb.App.CallLive, "/call/tok")

      :ok = Surfaces.rename(old, new)

      assert Surfaces.count(new) == 1
      assert Surfaces.count(old) == 0
      assert Surfaces.open?(new, "/call/tok")

      close(call)
    end

    test "the change is announced on the name the tabs are still listening to" do
      old = unique_nick("ren")
      new = unique_nick("ren")
      call = start_surface(old, RetroHexChatWeb.App.CallLive, "/call/tok")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, RetroHexChat.Topics.surfaces(old))
      :ok = Surfaces.rename(old, new)

      assert_receive {:nick_changed, %{new_nick: ^new}}

      close(call)
    end

    test "renaming somebody with nothing open is not an error" do
      assert :ok = Surfaces.rename(unique_nick("ren"), unique_nick("ren"))
    end

    # Only the case changed, so the key is the same key: re-keying it would
    # delete the entry and put it back empty.
    test "a change of case alone keeps the tabs" do
      nickname = unique_nick("Ren")
      call = start_surface(nickname, RetroHexChatWeb.App.CallLive, "/call/tok")

      :ok = Surfaces.rename(nickname, String.upcase(nickname))

      assert Surfaces.count(nickname) == 1

      close(call)
    end
  end

  defp assert_eventually(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries <= 0 -> flunk("condition was not met before timeout")
      true -> Process.sleep(20) && assert_eventually(fun, retries - 1)
    end
  end
end
