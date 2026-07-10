defmodule RetroHexChat.GroupCall.RateLimiterTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.GroupCall.RateLimiter

  setup do
    table = :ets.new(:group_call_rate_limiter_test, [:set, :public])
    {:ok, table: table}
  end

  test "allows requests within a sliding window", %{table: table} do
    assert :ok = RateLimiter.check(table, {:join, 1}, {2, 1_000})
    assert :ok = RateLimiter.check(table, {:join, 1}, {2, 1_000})
  end

  test "returns retry seconds after the limit is exceeded", %{table: table} do
    assert :ok = RateLimiter.check(table, {:signal, "room", 1}, {1, 1_000})

    assert {:error, {:rate_limited, seconds}} =
             RateLimiter.check(table, {:signal, "room", 1}, {1, 1_000})

    assert seconds >= 1
  end

  test "different keys are isolated", %{table: table} do
    assert :ok = RateLimiter.check(table, {:create, 1}, {1, 1_000})

    assert {:error, {:rate_limited, _seconds}} =
             RateLimiter.check(table, {:create, 1}, {1, 1_000})

    assert :ok = RateLimiter.check(table, {:create, 2}, {1, 1_000})
  end
end
