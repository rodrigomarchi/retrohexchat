defmodule RetroHexChat.Chat.AliasEntry do
  @moduledoc """
  Value object representing a single user-defined alias.
  Stored without the "/" prefix (e.g., name: "hi", expansion: "/me says hello!").
  """

  @type t :: %__MODULE__{
          name: String.t(),
          expansion: String.t(),
          position: non_neg_integer()
        }

  @enforce_keys [:name, :expansion]
  defstruct [:name, :expansion, position: 0]

  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      expansion: Keyword.fetch!(opts, :expansion),
      position: Keyword.get(opts, :position, 0)
    }
  end
end
