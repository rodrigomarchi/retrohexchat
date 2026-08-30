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
  defp start_surface(nickname, kind) do
    test = self()

    pid =
      spawn(fn ->
        :ok = Surfaces.open(nickname, kind)
        send(test, {:registered, self()})

        receive do
          :close -> :ok
          :crash -> exit(:boom)
        end
      end)

    assert_receive {:registered, ^pid}, 1_000
    pid
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
  end

  defp assert_eventually(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries <= 0 -> flunk("condition was not met before timeout")
      true -> Process.sleep(20) && assert_eventually(fun, retries - 1)
    end
  end
end
