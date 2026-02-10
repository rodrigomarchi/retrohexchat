defmodule RetroHexChat.LoadTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :load
  @moduletag timeout: 120_000

  alias RetroHexChat.Channels.{Server, Supervisor}

  defp start_channel(channel_name) do
    {:ok, pid} = Supervisor.start_child(channel_name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    {:ok, pid}
  end

  describe "concurrent users" do
    @tag timeout: 120_000
    test "50 users across 10 channels with message delivery" do
      channels =
        for i <- 1..10, do: "#load-test-#{System.unique_integer([:positive])}-#{i}"

      # Start all channels
      for ch <- channels, do: start_channel(ch)

      # Subscribe to all channels to verify message delivery
      for ch <- channels do
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{ch}")
      end

      # 50 users, distributed across 10 channels (5 per channel)
      tasks =
        for i <- 1..50 do
          channel = Enum.at(channels, rem(i - 1, 10))
          nickname = "loaduser_#{i}"

          Task.async(fn ->
            {:ok, _} = Server.join(channel, nickname)
            :ok = Server.send_message(channel, nickname, "Message from #{nickname}")
            {channel, nickname}
          end)
        end

      # All tasks should complete within 10 seconds
      results = Task.await_many(tasks, 10_000)
      assert length(results) == 50

      # Verify all messages were delivered via PubSub
      # We also receive user_joined events, so we filter for new_message
      received_messages =
        for _ <- 1..50 do
          receive do
            %{event: "new_message", payload: %{content: "Message from " <> _} = msg} -> msg
          after
            5000 -> flunk("Timed out waiting for PubSub message")
          end
        end

      assert length(received_messages) == 50

      # Verify channel states
      for ch <- channels do
        {:ok, state} = Server.get_state(ch)
        assert state.member_count == 5
      end

      # Cleanup
      for {ch, nick} <- results do
        Server.part(ch, nick)
      end
    end
  end
end
