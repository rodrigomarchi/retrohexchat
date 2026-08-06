defmodule RetroHexChat.Jobs.TrustedDeviceCleanupWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Accounts.{ChatDeviceSession, TrustedDevice, TrustedDevices}
  alias RetroHexChat.Jobs.{ChatDeviceSessionCleanupWorker, TrustedDeviceExpiryWorker}
  alias RetroHexChat.Services.Queries

  test "trusted device expiry worker revokes expired devices and emits telemetry" do
    nick = nick("WorkerExp")
    {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
    {:ok, %{device: device}} = TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

    device
    |> TrustedDevice.changeset(%{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)})
    |> Repo.update!()

    attach_telemetry([:retro_hex_chat, :trusted_devices, :expire, :stop])

    assert {:ok, summary} =
             TrustedDeviceExpiryWorker.perform(%Oban.Job{
               args: %{"limit" => 10}
             })

    assert summary.candidates == 1
    assert summary.expired_devices == 1
    assert Repo.get!(TrustedDevice, device.id).revoked_at

    assert_receive {:telemetry_event, [:retro_hex_chat, :trusted_devices, :expire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "trusted_devices"
    assert metadata.operation == "expire"
    assert metadata.result == "ok"
    assert metadata.expired_devices == 1
  end

  test "chat device session cleanup worker closes stale sessions and emits telemetry" do
    nick = nick("WorkerSess")
    {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
    {:ok, session} = TrustedDevices.record_session_start(nick, nil, %{})

    old = DateTime.utc_now() |> DateTime.add(-600, :second)

    from(stored in ChatDeviceSession, where: stored.id == ^session.id)
    |> Repo.update_all(set: [last_seen_at: old])

    attach_telemetry([:retro_hex_chat, :trusted_devices, :session_cleanup, :stop])

    assert {:ok, summary} =
             ChatDeviceSessionCleanupWorker.perform(%Oban.Job{
               args: %{"limit" => 10, "stale_after_seconds" => 300}
             })

    assert summary.candidates == 1
    assert summary.closed_sessions == 1
    assert Repo.get!(ChatDeviceSession, session.id).disconnected_at

    assert_receive {:telemetry_event,
                    [:retro_hex_chat, :trusted_devices, :session_cleanup, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "trusted_devices"
    assert metadata.operation == "session_cleanup"
    assert metadata.result == "ok"
    assert metadata.closed_sessions == 1
  end

  defp nick(prefix), do: "#{prefix}#{System.unique_integer([:positive]) |> rem(100_000)}"

  defp attach_telemetry(event) do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [event],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
