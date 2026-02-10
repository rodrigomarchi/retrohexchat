defmodule RetroHexChat.Channels.RegistryTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.Registry

  describe "registry_name/0" do
    test "returns the correct atom" do
      assert Registry.registry_name() == RetroHexChat.Channels.ChannelRegistry
    end
  end

  describe "via_tuple/1" do
    test "returns {:via, Registry, {atom, String}} format" do
      result = Registry.via_tuple("#test")
      assert {:via, Elixir.Registry, {RetroHexChat.Channels.ChannelRegistry, "#test"}} = result
    end
  end

  describe "lookup/1" do
    test "returns {:error, :not_found} for non-existent channel" do
      assert {:error, :not_found} = Registry.lookup("#nonexistent_reg_test")
    end

    test "returns {:ok, pid} for existing channel" do
      {:ok, pid} = RetroHexChat.Channels.Supervisor.start_child("#reg_lookup_test")
      assert {:ok, ^pid} = Registry.lookup("#reg_lookup_test")
      GenServer.stop(pid)
    end
  end
end
