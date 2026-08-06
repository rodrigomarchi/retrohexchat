defmodule RetroHexChat.Jobs.RegisteredNickExpiryWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Jobs.RegisteredNickExpiryWorker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.Queries

  test "purges inactive registered nicks and emits telemetry" do
    register_nick("WorkerOldNick", "pass12345", 8)

    attach_telemetry()

    assert {:ok, result} = RegisteredNickExpiryWorker.perform(%Oban.Job{})

    assert result.expired_count == 1
    assert result.candidate_count == 1
    assert result.purged_count == 1
    assert result.purged_names == ["WorkerOldNick"]
    assert Queries.find_by_nickname("WorkerOldNick") == nil

    assert_receive {:telemetry_event, [:retro_hex_chat, :services, :nicks, :expire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "services"
    assert metadata.operation == "nicks_expire"
    assert metadata.domain == "maintenance"
    assert metadata.result == "ok"
    assert metadata.expired_count == 1
    assert metadata.candidate_count == 1
    assert metadata.purged_count == 1

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, %{context: "services", operation: "nicks_expire"}}
  end

  test "is idempotent and unique while an incomplete sweep exists" do
    register_nick("WorkerDueNick", "pass12345", 8)

    assert {:ok, _job} =
             %{}
             |> RegisteredNickExpiryWorker.new()
             |> Oban.insert()

    assert {:ok, _conflict} =
             %{}
             |> RegisteredNickExpiryWorker.new()
             |> Oban.insert()

    assert [_job] = all_enqueued(worker: RegisteredNickExpiryWorker, queue: :maintenance)

    assert %{success: 1, failure: 0} =
             Oban.drain_queue(queue: :maintenance, with_scheduled: true, with_limit: 1)

    assert Queries.find_by_nickname("WorkerDueNick") == nil

    assert {:ok, %{purged_count: 0}} = RegisteredNickExpiryWorker.perform(%Oban.Job{})
  end

  defp register_nick(nickname, password, last_seen_days_ago) do
    {:ok, nick} = Queries.insert_registered_nick(nickname, password)
    last_seen = DateTime.add(DateTime.utc_now(), -last_seen_days_ago, :day)

    nick
    |> Ecto.Changeset.change(last_seen_at: last_seen)
    |> Repo.update!()
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :services, :nicks, :expire, :stop],
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
