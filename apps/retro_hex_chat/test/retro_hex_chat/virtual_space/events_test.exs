defmodule RetroHexChat.VirtualSpace.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.VirtualSpace.Events

  describe "emit_session_created/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :session_created]
        ])

      Events.emit_session_created("tok-1", "#retro")

      assert_received {[:retro_hex_chat, :virtual_space, :session_created], ^ref, %{count: 1},
                       %{channel: "#retro"}}
    end
  end

  describe "emit_participant_joined/1" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :participant_joined]
        ])

      Events.emit_participant_joined("tok-1")

      assert_received {[:retro_hex_chat, :virtual_space, :participant_joined], ^ref, %{count: 1},
                       %{token: "tok-1"}}
    end
  end

  describe "emit_session_ended/2" do
    test "emits telemetry event tagged with the terminal reason" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :session_ended]
        ])

      Events.emit_session_ended("tok-1", "expired")

      assert_received {[:retro_hex_chat, :virtual_space, :session_ended], ^ref, %{count: 1},
                       %{status: "expired"}}
    end
  end
end
