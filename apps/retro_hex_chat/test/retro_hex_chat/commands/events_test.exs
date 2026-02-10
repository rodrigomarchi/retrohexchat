defmodule RetroHexChat.Commands.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Events

  describe "emit_command_executed/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :commands, :command_executed]
        ])

      Events.emit_command_executed("join", "alice")

      assert_received {[:retro_hex_chat, :commands, :command_executed], ^ref, %{count: 1},
                       %{command: "join", nickname: "alice"}}
    end
  end
end
