defmodule RetroHexChat.Chat.PerformEntry do
  @moduledoc """
  In-memory runtime struct for a single perform command entry.
  """

  @type t :: %__MODULE__{
          command: String.t(),
          position: non_neg_integer()
        }

  @enforce_keys [:command]
  defstruct [:command, position: 0]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end
end
