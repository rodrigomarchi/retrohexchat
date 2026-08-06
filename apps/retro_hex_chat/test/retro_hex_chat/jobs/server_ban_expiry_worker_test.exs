defmodule RetroHexChat.Jobs.ServerBanExpiryWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Admin.{BanCache, ServerBan, ServerBans}
  alias RetroHexChat.Jobs.ServerBanExpiryWorker

  setup do
    on_exit(fn ->
      Enum.each(~w(ExpiredBan FutureBan DueBan), &BanCache.remove/1)
    end)

    :ok
  end

  test "expires due server bans, keeps future bans, and emits telemetry" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -60, :second)
    future = DateTime.add(now, 60, :second)

    {:ok, _expired} = ServerBans.ban("ExpiredBan", "Admin", "done", past)
    {:ok, _future} = ServerBans.ban("FutureBan", "Admin", "later", future)

    assert ServerBans.banned?("ExpiredBan")
    assert ServerBans.banned?("FutureBan")
    assert ServerBans.expired_count(now) == 1

    attach_telemetry()

    assert {:ok, 1} = ServerBanExpiryWorker.perform(%Oban.Job{})

    refute ServerBans.banned?("ExpiredBan")
    assert ServerBans.banned?("FutureBan")
    assert ServerBans.expired_count(now) == 0

    refute Repo.get_by!(ServerBan, nickname: "ExpiredBan").active
    assert Repo.get_by!(ServerBan, nickname: "FutureBan").active

    assert_receive {:telemetry_event, [:retro_hex_chat, :admin, :server_bans, :expire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "admin"
    assert metadata.operation == "server_bans_expire"
    assert metadata.domain == "maintenance"
    assert metadata.result == "ok"
    assert metadata.expired_count == 1

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, %{context: "admin", operation: "server_bans_expire"}}
  end

  test "is idempotent and unique while an incomplete sweep exists" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -60, :second)

    {:ok, _expired} = ServerBans.ban("DueBan", "Admin", "done", past)

    assert {:ok, _job} =
             %{}
             |> ServerBanExpiryWorker.new()
             |> Oban.insert()

    assert {:ok, _conflict} =
             %{}
             |> ServerBanExpiryWorker.new()
             |> Oban.insert()

    assert [_job] = all_enqueued(worker: ServerBanExpiryWorker, queue: :maintenance)

    assert %{success: 1, failure: 0} =
             Oban.drain_queue(queue: :maintenance, with_scheduled: true, with_limit: 1)

    refute ServerBans.banned?("DueBan")
    assert ServerBans.expired_count(now) == 0

    assert {:ok, 0} = ServerBanExpiryWorker.perform(%Oban.Job{})
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :admin, :server_bans, :expire, :stop],
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
