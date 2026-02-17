defmodule RetroHexChat.P2P.SignalingRateLimit.ETSTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.SignalingRateLimit.ETS, as: SignalLimiter

  @moduletag :unit

  setup do
    table = :ets.new(:test_signal_rate_limits, [:set, :public])
    %{table: table}
  end

  describe "check_signal_rate/3" do
    test "allows up to 100 signals per minute", %{table: table} do
      for _ <- 1..100 do
        assert :ok = SignalLimiter.check_signal_rate("token-1", 42, table)
      end
    end

    test "rejects 101st signal within window", %{table: table} do
      for _ <- 1..100 do
        :ok = SignalLimiter.check_signal_rate("token-1", 42, table)
      end

      assert {:error, :rate_limited} = SignalLimiter.check_signal_rate("token-1", 42, table)
    end

    test "different users have independent limits", %{table: table} do
      for _ <- 1..100 do
        :ok = SignalLimiter.check_signal_rate("token-1", 1, table)
      end

      assert {:error, :rate_limited} = SignalLimiter.check_signal_rate("token-1", 1, table)

      # User 2 should still be fine
      assert :ok = SignalLimiter.check_signal_rate("token-1", 2, table)
    end

    test "resets after window expires", %{table: table} do
      # Fill up with a tiny window
      for _ <- 1..100 do
        :ok = SignalLimiter.check_signal_rate("token-1", 42, table, 50)
      end

      assert {:error, :rate_limited} = SignalLimiter.check_signal_rate("token-1", 42, table, 50)

      Process.sleep(60)

      assert :ok = SignalLimiter.check_signal_rate("token-1", 42, table, 50)
    end
  end

  describe "behaviour compliance" do
    test "implements SignalingRateLimit behaviour" do
      behaviours =
        SignalLimiter.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert RetroHexChat.P2P.SignalingRateLimit in behaviours
    end
  end
end
