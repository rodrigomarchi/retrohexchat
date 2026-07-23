defmodule RetroHexChat.ObservabilityTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Observability

  setup do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    events = [
      [:retro_hex_chat, :chat, :message, :send, :start],
      [:retro_hex_chat, :chat, :message, :send, :stop],
      [:retro_hex_chat, :commands, :dispatch, :stop],
      [:retro_hex_chat, :chat, :message, :send, :exception],
      [:retro_hex_chat, :observability, :operation, :stop],
      [:retro_hex_chat, :observability, :operation, :exception]
    ]

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  test "span emits specific and generic stop events" do
    assert {:ok, :sent} =
             Observability.span(
               [:retro_hex_chat, :chat, :message, :send],
               %{conversation_type: "channel", message_type: "message"},
               fn -> {:ok, :sent} end
             )

    assert_receive {:telemetry_event, [:retro_hex_chat, :chat, :message, :send, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert duration >= 0
    assert metadata.context == "chat"
    assert metadata.operation == "message_send"
    assert metadata.result == "ok"

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, generic_metadata}

    assert generic_metadata.context == "chat"
    assert generic_metadata.operation == "message_send"
  end

  test "span accepts custom result classification" do
    assert {:socket, {:error, "bad command"}} =
             Observability.span(
               [:retro_hex_chat, :commands, :dispatch],
               %{command: "join"},
               fn -> {:socket, {:error, "bad command"}} end,
               fn
                 {_socket, {:error, _reason}} -> %{result: "error", reason: "command_error"}
                 {_socket, _result} -> %{result: "ok"}
               end
             )

    assert_receive {:telemetry_event, [:retro_hex_chat, :commands, :dispatch, :stop],
                    %{duration: _}, metadata}

    assert metadata.context == "commands"
    assert metadata.operation == "dispatch"
    assert metadata.result == "error"
    assert metadata.reason == "command_error"
  end

  test "span emits exception events and reraises" do
    assert_raise RuntimeError, "boom", fn ->
      Observability.span([:retro_hex_chat, :chat, :message, :send], %{}, fn ->
        raise "boom"
      end)
    end

    assert_receive {:telemetry_event, [:retro_hex_chat, :chat, :message, :send, :exception],
                    %{duration: _}, metadata}

    assert metadata.context == "chat"
    assert metadata.operation == "message_send"
    assert metadata.result == "error"
    assert metadata.kind == "error"

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :exception],
                    %{duration: _}, generic_metadata}

    assert generic_metadata.result == "error"
  end
end
