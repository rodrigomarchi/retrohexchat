defmodule RetroHexChat.RateLimit.LimiterTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.RateLimit.Limiter

  setup do
    # Create a test ETS table for each test
    table = :ets.new(:test_rate_limit, [:set, :public])
    {:ok, table: table}
  end

  describe "check_rate/3" do
    test "allows messages within rate limit", %{table: table} do
      assert :ok = Limiter.check_rate(table, "user1", :message)
    end

    test "blocks messages when limit exceeded", %{table: table} do
      for _ <- 1..5 do
        assert :ok = Limiter.check_rate(table, "user1", :message)
      end

      assert {:error, :rate_limited} = Limiter.check_rate(table, "user1", :message)
    end

    test "allows commands within rate limit", %{table: table} do
      assert :ok = Limiter.check_rate(table, "user1", :command)
      assert :ok = Limiter.check_rate(table, "user1", :command)
    end

    test "blocks commands when limit exceeded", %{table: table} do
      assert :ok = Limiter.check_rate(table, "user1", :command)
      assert :ok = Limiter.check_rate(table, "user1", :command)
      assert {:error, :rate_limited} = Limiter.check_rate(table, "user1", :command)
    end

    test "different users have independent limits", %{table: table} do
      for _ <- 1..5 do
        Limiter.check_rate(table, "user1", :message)
      end

      assert {:error, :rate_limited} = Limiter.check_rate(table, "user1", :message)
      assert :ok = Limiter.check_rate(table, "user2", :message)
    end
  end

  describe "muted?/2" do
    test "returns false for non-muted user", %{table: table} do
      refute Limiter.muted?(table, "user1")
    end

    test "returns true after exceeding rate limit", %{table: table} do
      for _ <- 1..5 do
        Limiter.check_rate(table, "user1", :message)
      end

      Limiter.check_rate(table, "user1", :message)
      assert Limiter.muted?(table, "user1")
    end
  end

  describe "reset/2" do
    test "resets rate limit state for a user", %{table: table} do
      for _ <- 1..5 do
        Limiter.check_rate(table, "user1", :message)
      end

      assert {:error, :rate_limited} = Limiter.check_rate(table, "user1", :message)
      Limiter.reset(table, "user1")
      assert :ok = Limiter.check_rate(table, "user1", :message)
    end
  end

  describe "command rate limiting" do
    test "first command request initializes with command tokens consumed", %{table: table} do
      # First command consumes 1 command token
      assert :ok = Limiter.check_rate(table, "cmd_user", :command)
      # After first command, there should be 1 command token left (2-1=1)
      assert :ok = Limiter.check_rate(table, "cmd_user", :command)
      # Third command should be rate limited
      assert {:error, :rate_limited} = Limiter.check_rate(table, "cmd_user", :command)
    end
  end

  describe "mute expiry" do
    test "muted user is unblocked after mute duration expires", %{table: table} do
      # Exhaust message rate
      for _ <- 1..5 do
        Limiter.check_rate(table, "mute_user", :message)
      end

      # Trigger mute
      assert {:error, :rate_limited} = Limiter.check_rate(table, "mute_user", :message)
      assert Limiter.muted?(table, "mute_user")

      # Manipulate the ETS record to set muted_until to the past
      [{nick, msg, cmd, last, _muted_until}] = :ets.lookup(table, "mute_user")
      past = System.monotonic_time(:millisecond) - 1
      :ets.insert(table, {nick, msg, cmd, last, past})

      refute Limiter.muted?(table, "mute_user")
    end
  end
end
