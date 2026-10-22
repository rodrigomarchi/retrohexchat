defmodule RetroHexChat.RateLimit.Window do
  @moduledoc """
  Fixed-window counter in ETS: at most `max_count` hits per key in each
  `window_ms`, the window starting at the first hit.

  P2P session creation, P2P signaling and every group-call limit count this
  way. The answer to a refused hit is how long the window still blocks, in
  milliseconds; `seconds/1` rounds it up for a caller that speaks seconds.
  """

  @type table :: :ets.tid() | atom()
  @type limit :: {pos_integer(), pos_integer()}

  @spec check(table(), term(), limit()) :: :ok | {:error, {:rate_limited, pos_integer()}}
  def check(table, key, {max_count, window_ms}) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, key) do
      [{^key, count, window_start}] when now - window_start < window_ms ->
        if count < max_count do
          :ets.insert(table, {key, count + 1, window_start})
          :ok
        else
          {:error, {:rate_limited, max(1, window_ms - (now - window_start))}}
        end

      _absent_or_expired ->
        :ets.insert(table, {key, 1, now})
        :ok
    end
  end

  @doc "A wait in milliseconds as whole seconds, never zero."
  @spec seconds(pos_integer()) :: pos_integer()
  def seconds(ms), do: max(1, ceil(ms / 1_000))

  @spec reset(table(), term()) :: :ok
  def reset(table, key) do
    :ets.delete(table, key)
    :ok
  end
end
