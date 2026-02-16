defmodule RetroHexChat.P2P.SignalingRateLimitTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.SignalingRateLimit

  @moduletag :unit

  describe "behaviour definition" do
    test "defines check_signal_rate callback" do
      callbacks = SignalingRateLimit.behaviour_info(:callbacks)
      assert {:check_signal_rate, 2} in callbacks
    end
  end

  describe "noop implementation" do
    test "always returns :ok" do
      assert :ok = SignalingRateLimit.Noop.check_signal_rate("token123", 42)
    end
  end
end
