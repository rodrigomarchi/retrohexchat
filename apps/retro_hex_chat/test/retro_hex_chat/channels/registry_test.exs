defmodule RetroHexChat.Channels.RegistryTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.Registry

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
