defmodule RetroHexChat.VirtualSpace.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.VirtualSpace.Events

  describe "emit_participant_count/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :participant_count]
        ])

      Events.emit_participant_count("#test", 3)

      assert_received {[:retro_hex_chat, :virtual_space, :participant_count], ^ref, %{value: 3},
                       %{channel: "#test"}}
    end
  end

  describe "emit_step/4" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :step]
        ])

      Events.emit_step("#test", :rejected, :blocked, 42)

      assert_received {[:retro_hex_chat, :virtual_space, :step], ^ref, %{count: 1, duration: 42},
                       %{channel: "#test", result: :rejected, reason: :blocked}}
    end
  end
end
