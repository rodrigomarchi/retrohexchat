defmodule RetroHexChat.Chat.AutoJoinEntry do
  @moduledoc """
  In-memory runtime struct for a single auto-join channel entry.
  """

  @type t :: %__MODULE__{
          channel_name: String.t(),
          channel_key: String.t() | nil,
          position: non_neg_integer()
        }

  @enforce_keys [:channel_name]
  defstruct [:channel_name, :channel_key, position: 0]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end
end
