defmodule RetroHexChat.SystemInfo.Usage do
  @moduledoc """
  A consumed amount measured against the ceiling the runtime will allow.

  Atoms, ports and processes are all bounded resources whose interesting fact is
  not the count but the proximity to the limit: 55k atoms means nothing until
  you know the table holds a million. Pairing the two here keeps the percentage
  a property of the reading rather than arithmetic each caller repeats.

  Exhaustion of any of these ends the node, so `percent` is deliberately
  computed at full precision and rounded only for display.
  """

  @type t :: %__MODULE__{
          used: non_neg_integer(),
          limit: pos_integer(),
          percent: float()
        }

  @enforce_keys [:used, :limit, :percent]
  defstruct [:used, :limit, :percent]

  @doc "Pairs a reading with its ceiling."
  @spec new(non_neg_integer(), pos_integer()) :: t()
  def new(used, limit) when is_integer(used) and is_integer(limit) and limit > 0 do
    %__MODULE__{used: used, limit: limit, percent: used / limit * 100}
  end

  @doc """
  The percentage rounded for display.

  A gauge sitting at 0.04% reads as `0.0`, which is honest: the informative fact
  is that the resource is untouched, not the exact fraction.
  """
  @spec percent_rounded(t(), non_neg_integer()) :: float()
  def percent_rounded(%__MODULE__{percent: percent}, precision \\ 1) do
    Float.round(percent, precision)
  end
end
