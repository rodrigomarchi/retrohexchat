defmodule RetroHexChat.ProcessRegistryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.ProcessRegistry

  setup do
    name = :"process_registry_test_#{System.unique_integer([:positive])}"
    start_supervised!({Registry, keys: :unique, name: name})

    {:ok, registry: name}
  end

  # A registry forgets a dead process from its own partition process, so the
  # `:DOWN` this test received says the agent is gone — not that the registry
  # has noticed. The partition's own `:DOWN` was sent at the same exit and is
  # therefore already in its mailbox, and a synchronous call lands behind it.
  #
  # `Registry.unregister/2` is not that call: for a unique registry it writes to
  # ETS without reaching the partition at all, which a measurement caught after
  # it looked like a fix. Left as it stands, the lookup below is a race that
  # lost one `make ci` run in several.
  defp settle(registry) do
    registry
    |> Supervisor.which_children()
    |> Enum.each(fn {_id, partition, _type, _modules} -> :sys.get_state(partition) end)
  end

  defp start_under(registry, key) do
    via = ProcessRegistry.via_tuple(registry, key)
    {:ok, pid} = Agent.start_link(fn -> :registered end, name: via)

    pid
  end

  describe "via_tuple/2" do
    test "names a process through the registry it belongs to", ctx do
      assert {:via, Registry, {name, "#channel"}} =
               ProcessRegistry.via_tuple(ctx.registry, "#channel")

      assert name == ctx.registry
    end

    test "a key is whatever the caller already has to identify the process", ctx do
      assert {:via, Registry, {_name, {:direct_message_space, "abc"}}} =
               ProcessRegistry.via_tuple(ctx.registry, {:direct_message_space, "abc"})
    end

    test "starting under it is what makes the process findable", ctx do
      pid = start_under(ctx.registry, "#channel")

      assert ProcessRegistry.lookup(ctx.registry, "#channel") == {:ok, pid}
    end
  end

  describe "lookup/2" do
    test "a name nobody registered is not found rather than an empty list", ctx do
      assert ProcessRegistry.lookup(ctx.registry, "#never-started") == {:error, :not_found}
    end

    test "a process that has died is not found, which is an ordinary answer", ctx do
      pid = start_under(ctx.registry, "#closing")
      ref = Process.monitor(pid)

      Agent.stop(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      settle(ctx.registry)

      assert ProcessRegistry.lookup(ctx.registry, "#closing") == {:error, :not_found}
    end

    test "each key reaches its own process", ctx do
      first = start_under(ctx.registry, "#one")
      second = start_under(ctx.registry, "#two")

      assert ProcessRegistry.lookup(ctx.registry, "#one") == {:ok, first}
      assert ProcessRegistry.lookup(ctx.registry, "#two") == {:ok, second}
      refute first == second
    end
  end
end
