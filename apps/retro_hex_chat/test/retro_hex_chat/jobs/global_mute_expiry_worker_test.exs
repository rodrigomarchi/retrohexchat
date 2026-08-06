defmodule RetroHexChat.Jobs.GlobalMuteExpiryWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Admin.{GlobalMute, GlobalMutes}
  alias RetroHexChat.Jobs.GlobalMuteExpiryWorker

  setup do
    GlobalMutes.reload_cache()
    :ok
  end

  test "expires due mutes, clears cache, broadcasts and emits telemetry" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -120, :second)

    assert :ok = GlobalMutes.mute("WorkerMute", "Admin", nil, 60)
    mute = Repo.one!(GlobalMute)

    from(stored in GlobalMute, where: stored.id == ^mute.id)
    |> Repo.update_all(set: [expires_at: past])

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:WorkerMute")
    attach_telemetry([:retro_hex_chat, :admin, :global_mutes, :expire, :stop])

    assert {:ok, :expired} =
             GlobalMuteExpiryWorker.perform(%Oban.Job{
               args: %{"mute_id" => mute.id},
               attempt: 1,
               max_attempts: 3
             })

    refute GlobalMutes.muted?("WorkerMute")
    assert_receive {:user_unmuted, %{nickname: "WorkerMute"}}

    assert_receive {:telemetry_event, [:retro_hex_chat, :admin, :global_mutes, :expire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "admin"
    assert metadata.operation == "global_mutes_expire"
    assert metadata.result == "expired"
  end

  test "cancels jobs for invalid or irrelevant mute ids" do
    assert {:cancel, "invalid global mute id"} =
             GlobalMuteExpiryWorker.perform(%Oban.Job{args: %{"mute_id" => "bad"}})

    assert {:cancel, "global mute not found"} =
             GlobalMuteExpiryWorker.perform(%Oban.Job{args: %{"mute_id" => 123_456}})

    assert :ok = GlobalMutes.mute("PermanentMute", "Admin", nil, :permanent)
    mute = Repo.one!(GlobalMute)

    assert {:cancel, "global mute is permanent"} =
             GlobalMuteExpiryWorker.perform(%Oban.Job{args: %{"mute_id" => mute.id}})
  end

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
