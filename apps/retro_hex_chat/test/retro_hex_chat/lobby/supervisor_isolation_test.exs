defmodule RetroHexChat.Lobby.SupervisorIsolationTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Lobby.Supervisor, as: LobbySupervisor

  # One child per session, and the sessions have nothing to do with each other:
  # separate people, separate peer connections. A DynamicSupervisor's default
  # intensity — three restarts in five seconds — is sized to stop a crash loop
  # from spinning, not to hold a pool of independent children. So three
  # unrelated sessions failing close together took the supervisor down and every
  # other session with it: a whole lobby lost to one bad peer.
  #
  # Exercised with plain children rather than SessionServer, because what is
  # under test is the supervisor's restart intensity, not the session lifecycle.

  setup do
    name = :"lobby_isolation_#{System.unique_integer([:positive])}"
    {:ok, sup} = LobbySupervisor.start_link(name: name)
    on_exit(fn -> if Process.alive?(sup), do: Process.exit(sup, :kill) end)

    %{sup: sup, name: name}
  end

  defp start_child!(name) do
    spec = %{
      id: {:probe, System.unique_integer([:positive])},
      start: {Agent, :start_link, [fn -> :running end]},
      restart: :transient
    }

    {:ok, pid} = DynamicSupervisor.start_child(name, spec)
    pid
  end

  test "unrelated children failing together do not take the pool with them", %{
    sup: sup,
    name: name
  } do
    survivor = start_child!(name)
    survivor_ref = Process.monitor(survivor)

    for _ <- 1..10 do
      victim = start_child!(name)
      victim_ref = Process.monitor(victim)
      Process.exit(victim, :kill)
      assert_receive {:DOWN, ^victim_ref, :process, ^victim, :killed}, 1_000
    end

    assert Process.alive?(sup), "the supervisor gave up after unrelated children failed"
    refute_received {:DOWN, ^survivor_ref, :process, ^survivor, _}
    assert Process.alive?(survivor), "an unrelated session was taken down with the failures"

    # And the pool still accepts work.
    assert is_pid(start_child!(name))
  end
end
