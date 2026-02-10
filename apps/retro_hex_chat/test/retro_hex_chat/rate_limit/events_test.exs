defmodule RetroHexChat.RateLimit.EventsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.RateLimit.Events

  describe "emit_rate_limited/2" do
    test "emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :rate_limit, :rate_limited]
        ])

      Events.emit_rate_limited("alice", :message)

      assert_received {[:retro_hex_chat, :rate_limit, :rate_limited], ^ref, %{count: 1},
                       %{nickname: "alice", type: :message}}
    end
  end
end
