defmodule RetroHexChat.Chat.FavoriteEntry do
  @moduledoc """
  In-memory runtime struct for a single favorite channel entry.
  """

  @type t :: %__MODULE__{
          channel_name: String.t(),
          description: String.t(),
          password: String.t() | nil,
          auto_join: boolean(),
          position: non_neg_integer()
        }

  @enforce_keys [:channel_name]
  defstruct [:channel_name, :password, description: "", auto_join: false, position: 0]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end
end
