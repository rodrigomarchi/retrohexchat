defmodule RetroHexChat.Games.RateLimiter do
  @moduledoc """
  ETS sliding-window rate limiter for game session creation.
  Default: 5 sessions per 10 minutes per user.
  """

  alias RetroHexChat.Games.RateLimitTable

  @spec check_session_rate(integer()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check_session_rate(user_id) do
    {max_count, window_ms} =
      Application.get_env(:retro_hex_chat, :game_session_rate_limit, {5, 600_000})

    check_session_rate(RateLimitTable.table_name(), user_id, {max_count, window_ms})
  end

  @spec check_session_rate(:ets.tid() | atom(), integer(), {pos_integer(), pos_integer()}) ::
          :ok | {:error, {:rate_limited, pos_integer()}}
  def check_session_rate(table, user_id, {max_count, window_ms} \\ {5, 600_000}) do
    key = {:game_session_create, user_id}
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

          count < max_count ->
            :ets.insert(table, {key, count + 1, window_start})
            :ok

          true ->
            remaining_ms = window_ms - elapsed
            remaining_seconds = max(1, ceil(remaining_ms / 1_000))
            {:error, {:rate_limited, remaining_seconds}}
        end
    end
  end

  @spec reset(:ets.tid() | atom(), integer()) :: :ok
  def reset(table, user_id) do
    :ets.delete(table, {:game_session_create, user_id})
    :ok
  end
end
