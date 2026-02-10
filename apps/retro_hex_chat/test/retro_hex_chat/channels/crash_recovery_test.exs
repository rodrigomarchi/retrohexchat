defmodule RetroHexChat.Channels.CrashRecoveryTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  defp unique_channel, do: "#crash-#{System.unique_integer([:positive])}"

  defp wait_until(_fun, _interval, 0), do: flunk("Condition not met after retries")

  defp wait_until(fun, interval, retries) do
    if fun.() do
      :ok
    else
      Process.sleep(interval)
      wait_until(fun, interval, retries - 1)
    end
  end

  describe "crash recovery" do
    test "channel process is restarted after kill but starts fresh" do
      channel = unique_channel()
      {:ok, pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        case Registry.lookup(channel) do
          {:ok, p} -> Supervisor.stop_child(p)
          _ -> :ok
        end
      end)

      {:ok, _} = Server.join(channel, "user1")

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1000

      # With restart: :transient, :kill is an abnormal exit so DynamicSupervisor
      # will restart the process. The restarted process starts fresh with no members.
      # Wait for the new process to be registered.
      wait_until(
        fn ->
          case Registry.lookup(channel) do
            {:ok, new_pid} -> new_pid != pid
            _ -> false
          end
        end,
        100,
        30
      )

      {:ok, new_pid} = Registry.lookup(channel)
      assert new_pid != pid

      # The restarted process should have no members (fresh state)
      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 0
    end

    test "registered channel recovers persisted state from DB after restart" do
      channel = unique_channel()

      # Set up registered channel in DB
      import RetroHexChat.Factory

      insert(:registered_channel,
        name: channel,
        founder_nickname: "founder1",
        topic: "Recovered topic",
        modes: "+t"
      )

      # Start channel - it should load persisted state
      {:ok, pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        case Registry.lookup(channel) do
          {:ok, p} -> Supervisor.stop_child(p)
          _ -> :ok
        end
      end)

      {:ok, state} = Server.get_state(channel)
      assert state.topic == "Recovered topic"

      # Kill the process
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1000

      # Wait for the DynamicSupervisor to restart it (abnormal exit)
      wait_until(
        fn ->
          case Registry.lookup(channel) do
            {:ok, new_pid} -> new_pid != pid
            _ -> false
          end
        end,
        100,
        30
      )

      {:ok, new_pid} = Registry.lookup(channel)
      assert new_pid != pid

      # Verify recovered state from DB
      {:ok, new_state} = Server.get_state(channel)
      assert new_state.topic == "Recovered topic"
    end

    test "unregistered channel stops cleanly when last user parts" do
      channel = unique_channel()
      {:ok, pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        case Registry.lookup(channel) do
          {:ok, p} -> Supervisor.stop_child(p)
          _ -> :ok
        end
      end)

      {:ok, _} = Server.join(channel, "lonely")

      ref = Process.monitor(pid)
      :ok = Server.part(channel, "lonely")

      # Normal exit - :transient means it is NOT restarted
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000

      wait_until(
        fn -> Registry.lookup(channel) == {:error, :not_found} end,
        100,
        20
      )

      assert {:error, :not_found} = Registry.lookup(channel)
    end
  end
end
