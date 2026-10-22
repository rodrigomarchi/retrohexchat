defmodule RetroHexChat.P2P.SignalingRateLimit.ETS do
  @moduledoc """
  ETS sliding-window rate limiter for signaling messages.
  Default: 100 signals per 60 seconds per user.
  """

  @behaviour RetroHexChat.P2P.SignalingRateLimit

  alias RetroHexChat.P2P.RateLimitTable
  alias RetroHexChat.RateLimit.Window

  @default_max_count 100
  @default_window_ms 60_000

  @impl true
  @spec check_signal_rate(String.t(), integer()) ::
          :ok | {:error, {:rate_limited, non_neg_integer()}}
  def check_signal_rate(_session_token, user_id) do
    do_check(user_id, RateLimitTable.table_name(), @default_window_ms)
  end

  @spec check_signal_rate(String.t(), integer(), :ets.tid() | atom()) ::
          :ok | {:error, {:rate_limited, non_neg_integer()}}
  def check_signal_rate(_session_token, user_id, table) do
    do_check(user_id, table, @default_window_ms)
  end

  @spec check_signal_rate(String.t(), integer(), :ets.tid() | atom(), pos_integer()) ::
          :ok | {:error, {:rate_limited, non_neg_integer()}}
  def check_signal_rate(_session_token, user_id, table, window_ms) do
    do_check(user_id, table, window_ms)
  end

  # The refusal carries how long the window still blocks, in milliseconds: a
  # caller that cannot say when to try again leaves the client retrying into a
  # closed door.
  @spec do_check(integer(), :ets.tid() | atom(), pos_integer()) ::
          :ok | {:error, {:rate_limited, non_neg_integer()}}
  defp do_check(user_id, table, window_ms) do
    Window.check(table, {:signal, user_id}, {@default_max_count, window_ms})
  end
end
