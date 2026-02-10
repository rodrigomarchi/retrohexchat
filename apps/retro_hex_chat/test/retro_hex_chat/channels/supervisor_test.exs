defmodule RetroHexChat.Channels.SupervisorTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

  describe "start_child/1" do
    test "starts a channel process" do
      channel = "#test-#{System.unique_integer([:positive])}"
      assert {:ok, pid} = ChannelSupervisor.start_child(channel)
      assert Process.alive?(pid)
      # Cleanup
      ChannelSupervisor.stop_child(pid)
    end

    test "returns error for duplicate channel" do
      channel = "#test-dup-#{System.unique_integer([:positive])}"
      {:ok, pid} = ChannelSupervisor.start_child(channel)
      assert {:error, {:already_started, ^pid}} = ChannelSupervisor.start_child(channel)
      # Cleanup
      ChannelSupervisor.stop_child(pid)
    end
  end

  describe "stop_child/1" do
    test "stops a running channel process" do
      channel = "#test-stop-#{System.unique_integer([:positive])}"
      {:ok, pid} = ChannelSupervisor.start_child(channel)
      assert :ok = ChannelSupervisor.stop_child(pid)
      refute Process.alive?(pid)
    end

    test "stopping a non-existent pid returns error" do
      # Spawn and immediately kill a process to get a dead pid
      pid = spawn(fn -> :ok end)
      Process.sleep(10)
      refute Process.alive?(pid)

      assert {:error, :not_found} = ChannelSupervisor.stop_child(pid)
    end
  end
end
