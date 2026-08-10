defmodule RetroHexChat.Jobs.WorkerArgs do
  @moduledoc """
  Reads values out of an Oban job's `args` map.

  Job arguments arrive as decoded JSON, so a worker cannot assume a key is
  present or well typed. These readers fall back rather than raise, keeping a
  malformed argument from turning a maintenance run into a permanent failure.
  """

  @doc """
  Reads a positive integer under `key`, falling back to `default` for anything
  else — a missing key, a string, zero, or a negative number.
  """
  @spec positive_integer(map(), String.t(), pos_integer()) :: pos_integer()
  def positive_integer(args, key, default) do
    case Map.get(args, key) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
  end

  @doc """
  Parses a record id that may arrive as an integer or as its decimal string.

  Returns `:error` for anything that is not a positive integer, which lets the
  caller cancel the job instead of retrying an argument that will never parse.
  """
  @spec positive_id(term()) :: {:ok, pos_integer()} | :error
  def positive_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  def positive_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _result -> :error
    end
  end

  def positive_id(_id), do: :error
end
