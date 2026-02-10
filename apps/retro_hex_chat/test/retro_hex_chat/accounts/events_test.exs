defmodule RetroHexChat.Accounts.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.Events

  describe "emit_connected/1" do
    test "emits a telemetry event with the nickname" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :accounts, :connected]
        ])

      Events.emit_connected("Rodrigo")

      assert_received {[:retro_hex_chat, :accounts, :connected], ^ref, %{count: 1},
                       %{nickname: "Rodrigo"}}
    end
  end

  describe "emit_disconnected/1" do
    test "emits a telemetry event with the nickname" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :accounts, :disconnected]
        ])

      Events.emit_disconnected("Rodrigo")

      assert_received {[:retro_hex_chat, :accounts, :disconnected], ^ref, %{count: 1},
                       %{nickname: "Rodrigo"}}
    end
  end

  describe "emit_nick_changed/2" do
    test "emits a telemetry event with old and new nicknames" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :accounts, :nick_changed]
        ])

      Events.emit_nick_changed("OldNick", "NewNick")

      assert_received {[:retro_hex_chat, :accounts, :nick_changed], ^ref, %{count: 1},
                       %{old_nickname: "OldNick", new_nickname: "NewNick"}}
    end
  end
end
