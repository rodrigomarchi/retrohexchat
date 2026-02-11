defmodule RetroHexChat.Chat.HighlightWord do
  @moduledoc """
  In-memory runtime struct for a single highlight word entry.
  Maps a word to an optional background color from the 16 IRC color indices (0..15).
  """

  @type t :: %__MODULE__{
          word: String.t(),
          bg_color: non_neg_integer() | nil,
          position: non_neg_integer()
        }

  @enforce_keys [:word, :position]
  defstruct [:word, :bg_color, position: 0]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end
end
