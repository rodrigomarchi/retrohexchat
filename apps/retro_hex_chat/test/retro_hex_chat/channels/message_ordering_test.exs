defmodule RetroHexChat.Channels.MessageOrderingTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Server, Supervisor}

  defp unique_channel, do: "#msgord-#{System.unique_integer([:positive])}"

  defp start_channel(channel_name) do
    {:ok, pid} = Supervisor.start_child(channel_name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    {:ok, pid}
  end

  test "messages maintain causal ordering within a channel" do
    channel = unique_channel()
    {:ok, _pid} = start_channel(channel)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

    {:ok, _} = Server.join(channel, "sender")
    assert_receive {:user_joined, _}

    # Send 100 messages sequentially from the same user
    for i <- 1..100 do
      :ok = Server.send_message(channel, "sender", "Message #{i}")
    end

    # Collect all received messages
    messages =
      for _ <- 1..100 do
        assert_receive %{event: "new_message", payload: msg}, 5000
        msg
      end

    # Verify ordering: messages should arrive in the order they were sent
    contents = Enum.map(messages, & &1.content)
    expected = for i <- 1..100, do: "Message #{i}"
    assert contents == expected

    # Cleanup
    Server.part(channel, "sender")
  end

  test "messages from multiple senders maintain per-sender ordering" do
    channel = unique_channel()
    {:ok, _pid} = start_channel(channel)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

    # Join 3 users
    for nick <- ~w(alice bob carol) do
      {:ok, _} = Server.join(channel, nick)
      assert_receive {:user_joined, _}
    end

    # Each user sends 10 messages sequentially (all via GenServer calls)
    for nick <- ~w(alice bob carol) do
      for i <- 1..10 do
        :ok = Server.send_message(channel, nick, "#{nick}-#{i}")
      end
    end

    # Collect all 30 messages
    messages =
      for _ <- 1..30 do
        assert_receive %{event: "new_message", payload: msg}, 5000
        msg
      end

    # Per-sender ordering should be preserved
    for nick <- ~w(alice bob carol) do
      sender_msgs =
        messages
        |> Enum.filter(&(&1.author == nick))
        |> Enum.map(& &1.content)

      expected = for i <- 1..10, do: "#{nick}-#{i}"
      assert sender_msgs == expected, "#{nick}'s messages are out of order"
    end

    # Cleanup
    for nick <- ~w(alice bob carol), do: Server.part(channel, nick)
  end
end
