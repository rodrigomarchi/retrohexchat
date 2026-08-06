defmodule RetroHexChat.Jobs.RegisteredChannelExpiryWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Jobs.RegisteredChannelExpiryWorker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.Queries

  test "purges inactive registered channels and emits telemetry" do
    register_channel("#worker-expired", "Founder")
    backdate_channel_activity("#worker-expired", 8)

    attach_telemetry()

    assert {:ok, result} = RegisteredChannelExpiryWorker.perform(%Oban.Job{})

    assert result.candidate_count == 1
    assert result.purged_count == 1
    assert result.purged_names == ["#worker-expired"]
    assert Queries.find_registered_channel("#worker-expired") == nil

    assert_receive {:telemetry_event, [:retro_hex_chat, :services, :channels, :expire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "services"
    assert metadata.operation == "channels_expire"
    assert metadata.domain == "maintenance"
    assert metadata.result == "ok"
    assert metadata.candidate_count == 1
    assert metadata.purged_count == 1

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, %{context: "services", operation: "channels_expire"}}
  end

  test "is idempotent and unique while an incomplete sweep exists" do
    register_channel("#worker-due", "Founder")
    backdate_channel_activity("#worker-due", 8)

    assert {:ok, _job} =
             %{}
             |> RegisteredChannelExpiryWorker.new()
             |> Oban.insert()

    assert {:ok, _conflict} =
             %{}
             |> RegisteredChannelExpiryWorker.new()
             |> Oban.insert()

    assert [_job] = all_enqueued(worker: RegisteredChannelExpiryWorker, queue: :maintenance)

    assert %{success: 1, failure: 0} =
             Oban.drain_queue(queue: :maintenance, with_scheduled: true, with_limit: 1)

    assert Queries.find_registered_channel("#worker-due") == nil

    assert {:ok, %{purged_count: 0}} = RegisteredChannelExpiryWorker.perform(%Oban.Job{})
  end

  defp register_channel(name, founder) do
    {:ok, channel} = Queries.insert_registered_channel(name, founder)
    Queries.add_access(name, founder, "founder", founder)
    channel
  end

  defp backdate_channel_activity(name, days_ago) do
    activity_at = DateTime.add(DateTime.utc_now(), -days_ago, :day)

    Queries.find_registered_channel(name)
    |> Ecto.Changeset.change(last_activity_at: activity_at)
    |> Repo.update!()
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :services, :channels, :expire, :stop],
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
