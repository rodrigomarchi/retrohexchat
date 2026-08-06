defmodule RetroHexChat.Jobs.ChannelMuteExpiryWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{ChannelMute, Mutes}
  alias RetroHexChat.Jobs.ChannelMuteExpiryWorker

  test "expires due mutes and emits telemetry" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -120, :second)

    {:ok, mute} = Mutes.mute("#worker-mutes", "Oper", "Target", 60, now: past)

    attach_telemetry([:retro_hex_chat, :channels, :mutes, :expire, :stop])

    assert {:ok, :expired} =
             ChannelMuteExpiryWorker.perform(%Oban.Job{
               args: %{"mute_id" => mute.id},
               attempt: 1,
               max_attempts: 3
             })

    reloaded = Repo.get!(ChannelMute, mute.id)
    assert reloaded.revoked_at
    assert reloaded.revoke_reason == "expired"

    assert_receive {:telemetry_event, [:retro_hex_chat, :channels, :mutes, :expire, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "channels"
    assert metadata.operation == "mutes_expire"
    assert metadata.result == "expired"
  end

  test "cancels jobs for invalid or irrelevant mute ids" do
    assert {:cancel, "invalid channel mute id"} =
             ChannelMuteExpiryWorker.perform(%Oban.Job{args: %{"mute_id" => "bad"}})

    assert {:cancel, "channel mute not found"} =
             ChannelMuteExpiryWorker.perform(%Oban.Job{args: %{"mute_id" => 123_456}})

    {:ok, mute} = Mutes.mute("#worker-permanent", "Oper", "Target", :permanent)

    assert {:cancel, "channel mute is permanent"} =
             ChannelMuteExpiryWorker.perform(%Oban.Job{args: %{"mute_id" => mute.id}})
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
