defmodule RetroHexChat.Sweep do
  @moduledoc """
  A bounded maintenance pass over a batch of candidates.

  Each candidate is handed to a step that reports what happened to it, and the
  outcomes are tallied into a summary. The pass stops at the first error: a
  sweep that reports "ok" over a broken database is one nothing will ever
  retry, while a row somebody changed between the listing and the write is
  only skipped.
  """

  @typedoc """
  What one step reports: a counter to bump by one, a map of counters to add,
  or the error that ends the pass.
  """
  @type outcome :: {:ok, atom() | %{optional(atom()) => integer()}} | {:error, term()}

  @doc """
  Runs `step` over `candidates`, adding each outcome to `counters`.

  The summary carries `:candidates` (the batch size) beside the counters.
  """
  @spec tally([term()], %{optional(atom()) => integer()}, (term() -> outcome())) ::
          {:ok, map()} | {:error, term()}
  def tally(candidates, counters, step) do
    initial = Map.put(counters, :candidates, length(candidates))

    Enum.reduce_while(candidates, {:ok, initial}, fn candidate, {:ok, summary} ->
      case step.(candidate) do
        {:ok, counter} when is_atom(counter) -> {:cont, {:ok, add(summary, %{counter => 1})}}
        {:ok, increments} when is_map(increments) -> {:cont, {:ok, add(summary, increments)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Reads a positive integer option, falling back to `default` for anything
  else — missing, zero, negative or not an integer.
  """
  @spec positive_option(keyword(), atom(), pos_integer()) :: pos_integer()
  def positive_option(opts, key, default) do
    case Keyword.get(opts, key) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
  end

  defp add(summary, increments) do
    Enum.reduce(increments, summary, fn {key, amount}, acc ->
      Map.update!(acc, key, &(&1 + amount))
    end)
  end
end
