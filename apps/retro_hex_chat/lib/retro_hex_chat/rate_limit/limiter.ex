defmodule RetroHexChat.RateLimit.Limiter do
  @moduledoc """
  ETS-based token bucket rate limiter.
  5 messages/sec, 2 commands/sec per user.
  Mute for 10 seconds on violation.
  """

  @msg_rate 5
  @cmd_rate 2
  @mute_duration_ms 10_000

  @type table :: :ets.tid() | atom()

  @spec check_rate(table(), String.t(), :message | :command) :: :ok | {:error, :rate_limited}
  def check_rate(table, nickname, type) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, nickname) do
      [] ->
        # First request - initialize bucket
        {msg_tokens, cmd_tokens} = initial_tokens(type)
        :ets.insert(table, {nickname, msg_tokens, cmd_tokens, now, nil})
        :ok

      [{^nickname, _msg, _cmd, _last, muted_until}]
      when is_integer(muted_until) and now < muted_until ->
        {:error, :rate_limited}

      [{^nickname, msg_tokens, cmd_tokens, last_refill, _muted}] ->
        elapsed = now - last_refill
        refilled_msg = min(@msg_rate, msg_tokens + div(elapsed * @msg_rate, 1000))
        refilled_cmd = min(@cmd_rate, cmd_tokens + div(elapsed * @cmd_rate, 1000))

        case consume(type, refilled_msg, refilled_cmd) do
          {:ok, new_msg, new_cmd} ->
            :ets.insert(table, {nickname, new_msg, new_cmd, now, nil})
            :ok

          :rate_limited ->
            muted_until = now + @mute_duration_ms
            :ets.insert(table, {nickname, refilled_msg, refilled_cmd, now, muted_until})
            {:error, :rate_limited}
        end
    end
  end

  @spec muted?(table(), String.t()) :: boolean()
  def muted?(table, nickname) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, nickname) do
      [{^nickname, _, _, _, muted_until}]
      when is_integer(muted_until) and now < muted_until ->
        true

      _ ->
        false
    end
  end

  @spec reset(table(), String.t()) :: :ok
  def reset(table, nickname) do
    :ets.delete(table, nickname)
    :ok
  end

  defp initial_tokens(:message), do: {@msg_rate - 1, @cmd_rate}
  defp initial_tokens(:command), do: {@msg_rate, @cmd_rate - 1}

  defp consume(:message, msg_tokens, cmd_tokens) when msg_tokens > 0 do
    {:ok, msg_tokens - 1, cmd_tokens}
  end

  defp consume(:command, msg_tokens, cmd_tokens) when cmd_tokens > 0 do
    {:ok, msg_tokens, cmd_tokens - 1}
  end

  defp consume(_, _, _), do: :rate_limited
end
