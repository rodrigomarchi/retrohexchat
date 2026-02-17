defmodule RetroHexChat.P2P.SignalingRateLimit.ETS do
  @moduledoc """
  ETS sliding-window rate limiter for signaling messages.
  Default: 100 signals per 60 seconds per user.
  """

  @behaviour RetroHexChat.P2P.SignalingRateLimit

  alias RetroHexChat.P2P.RateLimitTable

  @default_max_count 100
  @default_window_ms 60_000

  @impl true
  @spec check_signal_rate(String.t(), integer()) :: :ok | {:error, :rate_limited}
  def check_signal_rate(_session_token, user_id) do
    do_check(user_id, RateLimitTable.table_name(), @default_window_ms)
  end

  @spec check_signal_rate(String.t(), integer(), :ets.tid() | atom()) ::
          :ok | {:error, :rate_limited}
  def check_signal_rate(_session_token, user_id, table) do
    do_check(user_id, table, @default_window_ms)
  end

  @spec check_signal_rate(String.t(), integer(), :ets.tid() | atom(), pos_integer()) ::
          :ok | {:error, :rate_limited}
  def check_signal_rate(_session_token, user_id, table, window_ms) do
    do_check(user_id, table, window_ms)
  end

  @spec do_check(integer(), :ets.tid() | atom(), pos_integer()) ::
          :ok | {:error, :rate_limited}
  defp do_check(user_id, table, window_ms) do
    key = {:signal, user_id}
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, key) do
      [] ->
        :ets.insert(table, {key, 1, now})
        :ok

      [{^key, count, window_start}] ->
        elapsed = now - window_start

        cond do
          elapsed >= window_ms ->
            :ets.insert(table, {key, 1, now})
            :ok

          count < @default_max_count ->
            :ets.insert(table, {key, count + 1, window_start})
            :ok

          true ->
            {:error, :rate_limited}
        end
    end
  end
end
