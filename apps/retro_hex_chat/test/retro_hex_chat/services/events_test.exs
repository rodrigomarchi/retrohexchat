defmodule RetroHexChat.Services.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Services.Events

  describe "emit_nick_registered/1" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :nickserv, :registered]
        ])

      Events.emit_nick_registered("alice")

      assert_received {[:retro_hex_chat, :nickserv, :registered], ^ref, %{count: 1},
                       %{nickname: "alice"}}
    end
  end

  describe "emit_nick_identified/1" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :nickserv, :identified]
        ])

      Events.emit_nick_identified("alice")

      assert_received {[:retro_hex_chat, :nickserv, :identified], ^ref, %{count: 1},
                       %{nickname: "alice"}}
    end
  end
end
