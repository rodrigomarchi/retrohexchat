defmodule RetroHexChat.Chat.CustomMenuItem do
  @moduledoc """
  Value object representing a single custom context menu item.
  """

  @type t :: %__MODULE__{
          menu_type: :nicklist | :channel | :chat,
          label: String.t(),
          command: String.t(),
          position: non_neg_integer()
        }

  @enforce_keys [:menu_type, :label, :command]
  defstruct [:menu_type, :label, :command, position: 0]

  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      menu_type: Keyword.fetch!(opts, :menu_type),
      label: Keyword.fetch!(opts, :label),
      command: Keyword.fetch!(opts, :command),
      position: Keyword.get(opts, :position, 0)
    }
  end
end
