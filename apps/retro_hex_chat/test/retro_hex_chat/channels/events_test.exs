defmodule RetroHexChat.Channels.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Events

  describe "emit_channel_created/1" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :channels, :channel_created]
        ])

      Events.emit_channel_created("#test")

      assert_received {[:retro_hex_chat, :channels, :channel_created], ^ref, %{count: 1},
                       %{channel: "#test"}}
    end
  end

  describe "emit_channel_destroyed/1" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :channels, :channel_destroyed]
        ])

      Events.emit_channel_destroyed("#test")

      assert_received {[:retro_hex_chat, :channels, :channel_destroyed], ^ref, %{count: 1},
                       %{channel: "#test"}}
    end
  end

  describe "emit_mode_changed/3" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :channels, :mode_changed]
        ])

      Events.emit_mode_changed("#test", "+m", "alice")

      assert_received {[:retro_hex_chat, :channels, :mode_changed], ^ref, %{count: 1},
                       %{channel: "#test", modes: "+m", by: "alice"}}
    end
  end

  describe "emit_topic_changed/3" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :channels, :topic_changed]
        ])

      Events.emit_topic_changed("#test", "New topic", "alice")

      assert_received {[:retro_hex_chat, :channels, :topic_changed], ^ref, %{count: 1},
                       %{channel: "#test", topic: "New topic", by: "alice"}}
    end
  end
end
