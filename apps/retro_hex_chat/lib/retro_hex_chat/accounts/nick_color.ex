defmodule RetroHexChat.Accounts.NickColor do
  @moduledoc """
  In-memory runtime struct for a single nick color override entry.
  Maps a target nickname to one of the 16 IRC color indices (0..15).
  """

  @type t :: %__MODULE__{
          target_nickname: String.t(),
          color_index: non_neg_integer()
        }

  @enforce_keys [:target_nickname, :color_index]
  defstruct [:target_nickname, :color_index]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end
end
