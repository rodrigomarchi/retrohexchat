defmodule RetroHexChat.Calls.EventsTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Calls.Events

  setup do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        Events.recovery_transition_event(),
        Events.client_error_event(),
        Events.signaling_replay_event()
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  test "emits low-cardinality recovery transition metadata" do
    Events.emit_recovery_transition(:p2p, :reconnecting, "ice_failed", %{
      attempt: "2",
      max_attempts: 3,
      manual_retry: "false",
      role: :peer,
      token: "secret-token",
      user_id: 123
    })

    assert_receive {:telemetry_event, event, %{count: 1}, metadata}

    assert event == Events.recovery_transition_event()
    assert metadata.surface == "p2p"
    assert metadata.state == "reconnecting"
    assert metadata.reason == "ice_failed"
    assert metadata.attempt == 2
    assert metadata.max_attempts == 3
    assert metadata.manual_retry == false
    assert metadata.role == "peer"
    refute Map.has_key?(metadata, :token)
    refute Map.has_key?(metadata, :user_id)
  end

  test "emits client error metadata" do
    Events.emit_client_error("group_call", "request_offer_failed", %{phase: :request_offer})

    assert_receive {:telemetry_event, event, %{count: 1}, metadata}

    assert event == Events.client_error_event()
    assert metadata.surface == "group_call"
    assert metadata.code == "request_offer_failed"
    assert metadata.phase == "request_offer"
  end

  test "emits signaling replay outcome metadata" do
    Events.emit_signaling_replay(:p2p, :served, %{
      reason: "liveview_reconnected",
      attempt: 1,
      event_count: 2
    })

    assert_receive {:telemetry_event, event, %{count: 1}, metadata}

    assert event == Events.signaling_replay_event()
    assert metadata.surface == "p2p"
    assert metadata.action == "served"
    assert metadata.reason == "liveview_reconnected"
    assert metadata.attempt == 1
    assert metadata.event_count == 2
  end
end
