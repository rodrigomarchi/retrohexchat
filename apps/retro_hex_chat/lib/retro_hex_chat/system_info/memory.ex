defmodule RetroHexChat.SystemInfo.Memory do
  @moduledoc """
  How the emulator's allocated bytes divide across its major consumers.

  `:erlang.memory/0` reports overlapping and partial figures; the six buckets
  kept here are the disjoint ones, and `other` absorbs the remainder so the
  parts always sum to `total`. That invariant is what lets the reading be drawn
  as a single segmented bar without the segments lying about their proportions.

  Which bucket dominates is the diagnosis: `processes` growing without bound is
  a leaking mailbox or state, `binary` is refc binaries outliving their owners,
  `ets` is a table nobody prunes.
  """

  @type bucket :: :processes | :atom | :binary | :code | :ets | :other

  @type t :: %__MODULE__{
          total: non_neg_integer(),
          processes: non_neg_integer(),
          atom: non_neg_integer(),
          binary: non_neg_integer(),
          code: non_neg_integer(),
          ets: non_neg_integer(),
          other: non_neg_integer()
        }

  @enforce_keys [:total, :processes, :atom, :binary, :code, :ets, :other]
  defstruct [:total, :processes, :atom, :binary, :code, :ets, :other]

  @buckets [:processes, :atom, :binary, :code, :ets, :other]

  @doc "Reads the current division of emulator memory."
  @spec current() :: t()
  def current do
    memory = :erlang.memory()

    total = memory[:total]
    processes = memory[:processes]
    atom = memory[:atom]
    binary = memory[:binary]
    code = memory[:code]
    ets = memory[:ets]

    %__MODULE__{
      total: total,
      processes: processes,
      atom: atom,
      binary: binary,
      code: code,
      ets: ets,
      other: total - processes - atom - binary - code - ets
    }
  end

  @doc "The buckets in display order, as `{bucket, bytes}` pairs."
  @spec buckets(t()) :: [{bucket(), non_neg_integer()}]
  def buckets(%__MODULE__{} = memory) do
    Enum.map(@buckets, fn bucket -> {bucket, Map.fetch!(memory, bucket)} end)
  end

  @doc """
  A bucket's share of the total, as a percentage.

  Guards against a zero total, which the runtime never reports but which a
  fabricated struct in a test legitimately can.
  """
  @spec share(t(), bucket()) :: float()
  def share(%__MODULE__{total: 0}, _bucket), do: 0.0

  def share(%__MODULE__{total: total} = memory, bucket) do
    Map.fetch!(memory, bucket) / total * 100
  end
end
