defmodule RetroHexChat.Channels.SimultaneousJoinsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Server, Supervisor}

  defp unique_channel, do: "#simjoin-#{System.unique_integer([:positive])}"

  defp start_channel(channel_name) do
    {:ok, pid} = Supervisor.start_child(channel_name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    {:ok, pid}
  end

  test "100 users join a single channel simultaneously" do
    channel = unique_channel()
    {:ok, _pid} = start_channel(channel)

    # Subscribe to verify join messages
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

    # Launch 100 concurrent joins
    tasks =
      for i <- 1..100 do
        Task.async(fn ->
          Server.join(channel, "simuser_#{i}")
        end)
      end

    results = Task.await_many(tasks, 10_000)

    # All should succeed
    successes = Enum.count(results, &match?({:ok, _}, &1))
    assert successes == 100, "Expected 100 successful joins, got #{successes}"

    # Verify final state
    {:ok, state} = Server.get_state(channel)
    assert state.member_count == 100

    # First joiner should be owner (the one that found 0 members)
    assert state.owners != []

    # All users should be in members list
    member_nicks = Enum.map(state.members, &elem(&1, 0))

    for i <- 1..100 do
      assert "simuser_#{i}" in member_nicks
    end

    # Verify all join messages received via PubSub
    for _ <- 1..100 do
      assert_receive {:user_joined, _}, 5000
    end

    # Cleanup
    for i <- 1..100 do
      Server.part(channel, "simuser_#{i}")
    end
  end
end
