defmodule RetroHexChat.Jobs.BotEventLogWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Jobs.BotEventLogWorker

  test "writes bot event log and emits telemetry" do
    {:ok, bot} = create_bot("EvtLogWorker")
    attach_telemetry()

    assert :ok =
             BotEventLogWorker.perform(%Oban.Job{
               args: %{
                 "bot_id" => bot.id,
                 "event_type" => "message_response",
                 "channel" => "#logs",
                 "metadata" => %{"source" => "test"}
               }
             })

    page = Queries.list_event_logs(bot.id)
    [event] = page.items

    assert event.event_type == "message_response"
    assert event.channel == "#logs"
    assert event.metadata == %{"source" => "test"}

    assert_receive {:telemetry_event, [:retro_hex_chat, :bots, :event_log, :write, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "bots"
    assert metadata.operation == "event_log_write"
    assert metadata.result == "ok"

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, %{context: "bots", operation: "event_log_write"}}
  end

  test "cancels when bot was removed" do
    assert {:cancel, "bot not found"} =
             BotEventLogWorker.perform(%Oban.Job{
               args: %{
                 "bot_id" => -1,
                 "event_type" => "message_response",
                 "channel" => "#logs",
                 "metadata" => %{}
               }
             })
  end

  defp create_bot(nickname) do
    Queries.create_bot(%{
      name: nickname,
      nickname: nickname,
      created_by: "admin",
      capabilities: %{}
    })
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :bots, :event_log, :write, :stop],
        [:retro_hex_chat, :observability, :operation, :stop]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
