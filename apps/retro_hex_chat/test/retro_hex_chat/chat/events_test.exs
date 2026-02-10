defmodule RetroHexChat.Chat.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Events

  describe "emit_message_sent/3" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :chat, :message_sent]
        ])

      Events.emit_message_sent("#lobby", "alice", "message")

      assert_received {[:retro_hex_chat, :chat, :message_sent], ^ref, %{count: 1},
                       %{channel: "#lobby", nickname: "alice", type: "message"}}
    end
  end

  describe "emit_message_persisted/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :chat, :message_persisted]
        ])

      Events.emit_message_persisted("#lobby", 42)

      assert_received {[:retro_hex_chat, :chat, :message_persisted], ^ref, %{count: 1},
                       %{channel: "#lobby", message_id: 42}}
    end
  end
end
