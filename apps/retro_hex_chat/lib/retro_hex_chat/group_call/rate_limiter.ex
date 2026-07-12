defmodule RetroHexChat.GroupCall.RateLimiter do
  @moduledoc """
  ETS sliding-window rate limiter for group-call lifecycle and signaling.

  The keys are intentionally separate from chat and P2P limits: group-call
  signaling can generate bursts of ICE candidates, while room creation and join
  attempts need much lower ceilings.
  """

  alias RetroHexChat.RateLimit.Table

  @type table :: :ets.tid() | atom()
  @type limit :: {pos_integer(), pos_integer()}

  @spec check_create_rate(integer()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check_create_rate(user_id) do
    limit = Application.get_env(:retro_hex_chat, :group_call_create_rate_limit, {3, 600_000})
    check(Table.table_name(), {:group_call_create, user_id}, limit)
  end

  @spec check_join_rate(integer()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check_join_rate(user_id) do
    limit = Application.get_env(:retro_hex_chat, :group_call_join_rate_limit, {20, 60_000})
    check(Table.table_name(), {:group_call_join, user_id}, limit)
  end

  @spec check_signal_rate(String.t(), integer()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check_signal_rate(room_token, user_id) do
    limit = Application.get_env(:retro_hex_chat, :group_call_signal_rate_limit, {300, 60_000})
    check(Table.table_name(), {:group_call_signal, room_token, user_id}, limit)
  end

  @spec check_reaction_rate(String.t(), integer()) ::
          :ok | {:error, {:rate_limited, pos_integer()}}
  def check_reaction_rate(room_token, user_id) do
    limit = Application.get_env(:retro_hex_chat, :group_call_reaction_rate_limit, {5, 10_000})
    check(Table.table_name(), {:group_call_reaction, room_token, user_id}, limit)
  end

  @spec check(table(), term(), limit()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check(table, key, {max_count, window_ms}) do
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
            {:error, {:rate_limited, max(1, ceil(remaining_ms / 1_000))}}
        end
    end
  end

  @spec reset(table(), term()) :: :ok
  def reset(table, key) do
    :ets.delete(table, key)
    :ok
  end
end
