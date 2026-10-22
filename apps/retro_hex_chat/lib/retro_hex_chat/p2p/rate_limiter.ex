defmodule RetroHexChat.P2P.RateLimiter do
  @moduledoc """
  ETS sliding-window rate limiter for P2P session creation.
  Default: 5 sessions per 10 minutes per user.
  """

  alias RetroHexChat.P2P.RateLimitTable
  alias RetroHexChat.RateLimit.Window

  @spec check_session_rate(integer()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check_session_rate(user_id) do
    {max_count, window_ms} =
      Application.get_env(:retro_hex_chat, :p2p_session_rate_limit, {5, 600_000})

    check_session_rate(RateLimitTable.table_name(), user_id, {max_count, window_ms})
  end

  @spec check_session_rate(:ets.tid() | atom(), integer(), {pos_integer(), pos_integer()}) ::
          :ok | {:error, {:rate_limited, pos_integer()}}
  def check_session_rate(table, user_id, limit \\ {5, 600_000}) do
    case Window.check(table, {:session_create, user_id}, limit) do
      :ok -> :ok
      {:error, {:rate_limited, ms}} -> {:error, {:rate_limited, Window.seconds(ms)}}
    end
  end

  @spec reset(:ets.tid() | atom(), integer()) :: :ok
  def reset(table, user_id), do: Window.reset(table, {:session_create, user_id})
end
