defmodule RetroHexChat.P2P.SignalingRateLimitTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.SignalingRateLimit

  @moduletag :unit

  describe "noop implementation" do
    test "always returns :ok" do
      assert :ok = SignalingRateLimit.Noop.check_signal_rate("token123", 42)
    end
  end
end
