defmodule RetroHexChat.Services.DisconnectCleanupTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.{Server, Supervisor}

  defp unique_channel, do: "#cleanup-#{System.unique_integer([:positive])}"

  describe "full disconnect cleanup sequence" do
    test "registered channel survives after last user leaves" do
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
  end
end
