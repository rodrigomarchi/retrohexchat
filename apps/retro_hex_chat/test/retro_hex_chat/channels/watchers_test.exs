defmodule RetroHexChat.Channels.WatchersTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.{Directory, Registry, Server, Supervisor}
  alias RetroHexChat.Topics

  defp unique_channel, do: "#watch-#{System.unique_integer([:positive])}"

  defp start_channel(channel) do
    {:ok, pid} = Supervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    pid
  end

  # A stand-in for a visitor's LiveView: a process that lives until told not to.
  defp visitor do
    pid = spawn(fn -> receive do: (:stop -> :ok) end)
    on_exit(fn -> send(pid, :stop) end)
    pid
  end

  defp directory_entry(channel), do: Enum.find(Directory.all(), &(&1.name == channel))

  describe "watch/3" do
    test "lists the visitor by guest name without making them a member" do
      channel = unique_channel()
      start_channel(channel)
      {:ok, _} = Server.join(channel, "founder")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

      assert {:ok, state} = Server.watch(channel, visitor(), "Guest1234")

      assert state.guests == ["Guest1234"]
      assert state.watcher_count == 1
      assert state.member_count == 1
      refute Enum.any?(state.members, fn {nick, _role} -> nick == "Guest1234" end)

      assert_receive {:watchers_changed, %{channel: ^channel, count: 1, guests: ["Guest1234"]}}
      refute_received {:user_joined, _}
      assert directory_entry(channel).watcher_count == 1
    end

    test "is idempotent for the same process" do
      channel = unique_channel()
      start_channel(channel)
      pid = visitor()

      {:ok, _} = Server.watch(channel, pid, "Guest1111")
      {:ok, state} = Server.watch(channel, pid, "Guest1111")

      assert state.guests == ["Guest1111"]
    end

    test "stops listing a visitor whose process ends" do
      channel = unique_channel()
      start_channel(channel)
      {:ok, _} = Server.join(channel, "founder")
      pid = visitor()
      {:ok, _} = Server.watch(channel, pid, "Guest2222")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

      send(pid, :stop)

      assert_receive {:watchers_changed, %{channel: ^channel, count: 0, guests: []}}
      {:ok, state} = Server.get_state(channel)
      assert state.guests == []
    end

    test "lists a visitor watching from several tabs once, until the last tab goes" do
      channel = unique_channel()
      start_channel(channel)
      {:ok, _} = Server.join(channel, "founder")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))
      first = visitor()
      second = visitor()

      {:ok, _} = Server.watch(channel, first, "Guest4444")
      assert_receive {:watchers_changed, %{count: 1, guests: ["Guest4444"]}}

      # The second tab changes nothing anybody sees, so nothing is said.
      {:ok, state} = Server.watch(channel, second, "Guest4444")
      assert state.guests == ["Guest4444"]
      assert state.watcher_count == 1
      assert directory_entry(channel).watcher_count == 1
      refute_received {:watchers_changed, _}

      :ok = Server.unwatch(channel, first)
      {:ok, state} = Server.get_state(channel)
      assert state.guests == ["Guest4444"]
      assert state.watcher_count == 1
      refute_received {:watchers_changed, _}

      :ok = Server.unwatch(channel, second)
      assert_receive {:watchers_changed, %{count: 0, guests: []}}
      assert directory_entry(channel).watcher_count == 0
    end

    test "counts two visitors as two" do
      channel = unique_channel()
      start_channel(channel)
      {:ok, _} = Server.watch(channel, visitor(), "Guest5555")
      {:ok, state} = Server.watch(channel, visitor(), "Guest6666")

      assert state.guests == ["Guest5555", "Guest6666"]
      assert state.watcher_count == 2
    end

    test "unwatch/2 drops the visitor" do
      channel = unique_channel()
      start_channel(channel)
      {:ok, _} = Server.join(channel, "founder")
      pid = visitor()
      {:ok, _} = Server.watch(channel, pid, "Guest3333")

      assert :ok = Server.unwatch(channel, pid)
      {:ok, state} = Server.get_state(channel)
      assert state.watcher_count == 0
    end

    test "refuses a channel a stranger may not see" do
      for mode <- ["+s", "+p", "+i"] do
        channel = unique_channel()
        start_channel(channel)
        {:ok, _} = Server.join(channel, "founder")
        :ok = Server.set_mode(channel, "founder", mode)

        assert {:error, :not_watchable} = Server.watch(channel, visitor(), "Guest4444")
      end

      keyed = unique_channel()
      start_channel(keyed)
      {:ok, _} = Server.join(keyed, "founder")
      :ok = Server.set_mode(keyed, "founder", "+k", ["secret"])

      assert {:error, :not_watchable} = Server.watch(keyed, visitor(), "Guest4444")
    end

    test "never brings an unregistered channel into being" do
      channel = unique_channel()

      assert {:error, :not_found} = Server.watch(channel, visitor(), "Guest5555")
      assert {:error, :not_found} = Registry.lookup(channel)
    end

    test "starts a registered channel nobody has entered yet" do
      channel = unique_channel()
      insert(:registered_channel, name: channel)

      assert {:ok, state} = Server.watch(channel, visitor(), "Guest6666")
      assert state.guests == ["Guest6666"]

      {:ok, pid} = Registry.lookup(channel)
      on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    end
  end

  describe "the default channel" do
    test "is watchable even when nobody is in it" do
      channel = unique_channel()
      restore_default_channel_on_exit()
      Application.put_env(:retro_hex_chat, :default_channel, channel)

      assert {:ok, state} = Server.watch(channel, visitor(), "Guest9999")
      assert state.guests == ["Guest9999"]

      {:ok, pid} = Registry.lookup(channel)
      on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    end
  end

  describe "closing the watch" do
    test "a mode that hides the channel ends every watch" do
      channel = unique_channel()
      start_channel(channel)
      {:ok, _} = Server.join(channel, "founder")
      {:ok, _} = Server.watch(channel, visitor(), "Guest7777")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

      :ok = Server.set_mode(channel, "founder", "+s")

      assert_receive {:watch_closed, %{channel: ^channel}}
      {:ok, state} = Server.get_state(channel)
      assert state.guests == []
    end
  end

  describe "an unregistered room" do
    test "stays up while a visitor watches it after the last member leaves" do
      channel = unique_channel()
      pid = start_channel(channel)
      {:ok, _} = Server.join(channel, "founder")
      {:ok, _} = Server.watch(channel, visitor(), "Guest8888")

      :ok = Server.part(channel, "founder")

      assert Process.alive?(pid)
      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 0
      assert state.guests == ["Guest8888"]
    end

    test "stops when the last watcher of an empty room goes" do
      channel = unique_channel()
      pid = start_channel(channel)
      watcher = visitor()
      {:ok, _} = Server.join(channel, "founder")
      {:ok, _} = Server.watch(channel, watcher, "Guest8889")
      :ok = Server.part(channel, "founder")
      ref = Process.monitor(pid)

      send(watcher, :stop)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "stops when the last watcher of an empty room unwatches" do
      channel = unique_channel()
      pid = start_channel(channel)
      watcher = visitor()
      {:ok, _} = Server.join(channel, "founder")
      {:ok, _} = Server.watch(channel, watcher, "Guest8890")
      :ok = Server.part(channel, "founder")
      ref = Process.monitor(pid)

      :ok = Server.unwatch(channel, watcher)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end
end
