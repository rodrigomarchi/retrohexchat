defmodule RetroHexChat.Presence.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Presence.Events

  describe "emit_user_online/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :presence, :user_online]
        ])

      Events.emit_user_online("alice", "#lobby")

      assert_received {[:retro_hex_chat, :presence, :user_online], ^ref, %{count: 1},
                       %{nickname: "alice", channel: "#lobby"}}
    end
  end

  describe "emit_user_offline/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :presence, :user_offline]
        ])

      Events.emit_user_offline("alice", "#lobby")

      assert_received {[:retro_hex_chat, :presence, :user_offline], ^ref, %{count: 1},
                       %{nickname: "alice", channel: "#lobby"}}
    end
  end

  describe "emit_user_away/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :presence, :user_away]
        ])

      Events.emit_user_away("alice", true)

      assert_received {[:retro_hex_chat, :presence, :user_away], ^ref, %{count: 1},
                       %{nickname: "alice", away: true}}
    end
  end
end
