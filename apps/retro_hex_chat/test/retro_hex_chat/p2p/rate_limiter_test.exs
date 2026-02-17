defmodule RetroHexChat.P2P.RateLimiterTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.RateLimiter

  @moduletag :unit

  setup do
    table = :ets.new(:test_p2p_rate_limits, [:set, :public])
    %{table: table}
  end

  describe "check_session_rate/2" do
    test "allows requests within limit", %{table: table} do
      for _ <- 1..5 do
        assert :ok = RateLimiter.check_session_rate(table, 42)
      end
    end

    test "rejects 6th request within window", %{table: table} do
      for _ <- 1..5 do
        assert :ok = RateLimiter.check_session_rate(table, 42)
      end

      assert {:error, {:rate_limited, remaining}} = RateLimiter.check_session_rate(table, 42)
      assert is_integer(remaining)
      assert remaining > 0
    end

    test "different users have independent limits", %{table: table} do
      for _ <- 1..5 do
        assert :ok = RateLimiter.check_session_rate(table, 1)
      end

      # User 1 is now rate limited
      assert {:error, _} = RateLimiter.check_session_rate(table, 1)

      # User 2 should still be fine
      assert :ok = RateLimiter.check_session_rate(table, 2)
    end

    test "resets after window expires", %{table: table} do
      # Use a very small window for this test
      for _ <- 1..5 do
        assert :ok = RateLimiter.check_session_rate(table, 99, {5, 50})
      end

      assert {:error, _} = RateLimiter.check_session_rate(table, 99, {5, 50})

      # Wait for window to expire
      Process.sleep(60)

      assert :ok = RateLimiter.check_session_rate(table, 99, {5, 50})
    end

    test "returns remaining seconds in error", %{table: table} do
      # Use 1-second window
      for _ <- 1..5 do
        :ok = RateLimiter.check_session_rate(table, 77, {5, 1_000})
      end

      assert {:error, {:rate_limited, remaining}} =
               RateLimiter.check_session_rate(table, 77, {5, 1_000})

      # Remaining should be 1 second (rounded up)
      assert remaining >= 1
      assert remaining <= 2
    end
  end

  describe "reset/2" do
    test "clears rate limit for a user", %{table: table} do
      for _ <- 1..5 do
        :ok = RateLimiter.check_session_rate(table, 42)
      end

      assert {:error, _} = RateLimiter.check_session_rate(table, 42)

      :ok = RateLimiter.reset(table, 42)

      assert :ok = RateLimiter.check_session_rate(table, 42)
    end
  end
end
