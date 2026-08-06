defmodule RetroHexChat.Jobs.BotScheduledMessageWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Channels
  alias RetroHexChat.Jobs.BotScheduledMessageWorker

  @channel "#bot-schedule-worker"

  setup do
    {:ok, channel_pid} = Channels.Supervisor.start_child(@channel)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{@channel}")

    on_exit(fn ->
      if Process.alive?(channel_pid), do: Channels.Supervisor.stop_child(channel_pid)
    end)

    :ok
  end

  test "fires scheduled message, persists last_fired and schedules successor" do
    {:ok, bot} = create_scheduled_bot("SchedWorkerBot", "sched1", "Tick from Oban")
    {:ok, _join} = Channels.Server.join(@channel, bot.nickname, nil, bot: true)

    attach_telemetry()

    assert :ok =
             BotScheduledMessageWorker.perform(%Oban.Job{
               args: %{"bot_id" => bot.id, "schedule_id" => "sched1"}
             })

    assert_receive %{
      event: "new_message",
      payload: %{author: "SchedWorkerBot", content: "Tick from Oban", channel: @channel}
    }

    updated = Queries.get_bot(bot.id)
    [schedule] = get_in(updated.capabilities, ["scheduler", "schedules"])

    assert schedule["id"] == "sched1"
    assert is_binary(schedule["last_fired"])

    assert_enqueued(
      worker: BotScheduledMessageWorker,
      queue: :bots,
      args: %{bot_id: bot.id, schedule_id: "sched1"}
    )

    assert_receive {:telemetry_event, [:retro_hex_chat, :bots, :scheduler, :fire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "bots"
    assert metadata.operation == "scheduler_fire"
    assert metadata.result == "ok"

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, %{context: "bots", operation: "scheduler_fire"}}
  end

  test "cancels when schedule was removed" do
    {:ok, bot} = create_scheduled_bot("SchedRemovedBot", "removed", "Nope")

    {:ok, updated} =
      Queries.update_bot(bot, %{capabilities: %{"scheduler" => %{"schedules" => []}}})

    assert {:cancel, "schedule removed"} =
             BotScheduledMessageWorker.perform(%Oban.Job{
               args: %{"bot_id" => updated.id, "schedule_id" => "removed"}
             })
  end

  defp create_scheduled_bot(nickname, schedule_id, message) do
    capabilities = %{
      "scheduler" => %{
        "enabled" => true,
        "schedules" => [
          %{
            "id" => schedule_id,
            "type" => "interval",
            "interval_min" => 1,
            "channel" => @channel,
            "message" => message,
            "last_fired" => nil
          }
        ]
      }
    }

    with {:ok, bot} <-
           Queries.create_bot(%{
             name: nickname,
             nickname: nickname,
             created_by: "admin",
             capabilities: capabilities
           }),
         {:ok, _config} <- Queries.add_channel_config(bot.id, @channel) do
      {:ok, bot}
    end
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :bots, :scheduler, :fire, :stop],
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
