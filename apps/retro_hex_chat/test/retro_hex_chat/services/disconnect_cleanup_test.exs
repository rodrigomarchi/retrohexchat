defmodule RetroHexChat.Services.DisconnectCleanupTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Services.NickServ

  defp unique_channel, do: "#cleanup-#{System.unique_integer([:positive])}"

  defp wait_until(fun, _interval, 0) do
    unless fun.(), do: flunk("Condition not met after retries")
  end

  defp wait_until(fun, interval, retries) do
    if fun.() do
      :ok
    else
      Process.sleep(interval)
      wait_until(fun, interval, retries - 1)
    end
  end

  setup do
    nick_server = :"nickserv_cleanup_#{System.unique_integer([:positive])}"
    {:ok, _} = NickServ.start_link(name: nick_server)

    %{nick_server: nick_server}
  end

  describe "full disconnect cleanup sequence" do
    test "cancels NickServ timer, parts all channels, stops empty unregistered channels",
         %{nick_server: nick_server} do
      # Step 1: Register a nickname via factory (for identify timer) and NickServ
      nickname = insert(:registered_nick).nickname
      NickServ.start_identify_timer(nickname, nick_server)

      # Allow the cast to be processed
      Process.sleep(20)

      # Step 2: Start channels and join them
      ch1 = unique_channel()
      ch2 = unique_channel()

      {:ok, pid1} = Supervisor.start_child(ch1)
      {:ok, pid2} = Supervisor.start_child(ch2)

      ref1 = Process.monitor(pid1)
      ref2 = Process.monitor(pid2)

      {:ok, _} = Server.join(ch1, nickname)
      {:ok, _} = Server.join(ch2, nickname)

      # Verify user is in both channels
      {:ok, state1} = Server.get_state(ch1)
      assert state1.member_count == 1

      {:ok, state2} = Server.get_state(ch2)
      assert state2.member_count == 1

      # Step 3: Execute cleanup sequence
      # Cancel NickServ timer
      NickServ.cancel_identify_timer(nickname, nick_server)
      # Allow cast to process
      Process.sleep(20)

      # Part all channels
      :ok = Server.part(ch1, nickname)
      :ok = Server.part(ch2, nickname)

      # Step 4: Verify timer is cancelled (no force_rename received)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")
      refute_receive {:force_rename, _}, 200

      # Step 5: Verify channels with no remaining users stopped
      assert_receive {:DOWN, ^ref1, :process, ^pid1, :normal}, 1000
      assert_receive {:DOWN, ^ref2, :process, ^pid2, :normal}, 1000

      wait_until(fn -> Registry.lookup(ch1) == {:error, :not_found} end, 50, 20)
      wait_until(fn -> Registry.lookup(ch2) == {:error, :not_found} end, 50, 20)

      assert {:error, :not_found} = Registry.lookup(ch1)
      assert {:error, :not_found} = Registry.lookup(ch2)
    end

    test "registered channel survives after last user leaves", %{nick_server: _nick_server} do
      nickname = build(:registered_nick).nickname
      channel = unique_channel()

      # Insert a registered channel so it persists
      insert(:registered_channel, name: channel, founder_nickname: nickname)

      {:ok, pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop_child(pid)
      end)

      {:ok, _} = Server.join(channel, nickname)
      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 1

      # Part the channel
      :ok = Server.part(channel, nickname)

      # Channel process should remain alive (registered channel)
      Process.sleep(100)
      assert Process.alive?(pid)

      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 0
    end

    test "user is removed from channels after cleanup", %{nick_server: _nick_server} do
      nickname = build(:registered_nick).nickname
      other_user = build(:registered_nick).nickname
      channel = unique_channel()

      {:ok, pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        if Process.alive?(pid), do: Supervisor.stop_child(pid)
      end)

      # Both users join
      {:ok, _} = Server.join(channel, nickname)
      {:ok, _} = Server.join(channel, other_user)

      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 2

      # Cleanup: user parts
      :ok = Server.part(channel, nickname)

      # Verify user is removed but channel remains (other user still in it)
      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 1
      refute {nickname, :regular} in state.members
      assert {other_user, :regular} in state.members
    end
  end
end
