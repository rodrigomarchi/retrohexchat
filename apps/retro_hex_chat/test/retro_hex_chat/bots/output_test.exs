defmodule RetroHexChat.Bots.OutputTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Output
  alias RetroHexChat.Channels
  alias RetroHexChat.Chat.Queries, as: ChatQueries

  defp unique_channel do
    "#bot-output-#{System.unique_integer([:positive])}"
  end

  defp start_channel(channel_name) do
    {:ok, pid} = Channels.Supervisor.start_child(channel_name)

    on_exit(fn ->
      if Process.alive?(pid), do: Channels.Supervisor.stop_child(pid)
    end)

    {:ok, pid}
  end

  test "blank output type falls back to a normal channel message" do
    channel = unique_channel()
    {:ok, _pid} = start_channel(channel)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")
    {:ok, _} = Channels.Server.join(channel, "WireBot")
    assert_receive {:user_joined, _}

    assert :ok =
             Output.send(channel, "WireBot", %{
               delivery: "public",
               type: "",
               content: "**BBC** | Story\n\n[Read full story](<https://example.com/story>)",
               content_format: "markdown"
             })

    assert_receive %{event: "new_message", payload: %{id: id, type: :message}}
    assert %{type: "message", content_format: "markdown"} = ChatQueries.get_message(id)
  end
end
