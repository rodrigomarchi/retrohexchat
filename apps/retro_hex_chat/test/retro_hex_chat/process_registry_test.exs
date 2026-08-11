defmodule RetroHexChat.ProcessRegistryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.ProcessRegistry

  setup do
    name = :"process_registry_test_#{System.unique_integer([:positive])}"
    start_supervised!({Registry, keys: :unique, name: name})

    {:ok, registry: name}
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
