defmodule RetroHexChat.Chat.AutoRespondRule do
  @moduledoc """
  Value object representing a single auto-respond rule.
  """

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          trigger_event: :on_join | :on_part | :on_nick_change,
          channel_filter: String.t() | nil,
          command: String.t(),
          enabled: boolean(),
          position: non_neg_integer()
        }

  @enforce_keys [:trigger_event, :command]
  defstruct [:trigger_event, :channel_filter, :command, id: 0, enabled: true, position: 0]

  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      id: Keyword.get(opts, :id, 0),
      trigger_event: Keyword.fetch!(opts, :trigger_event),
      channel_filter: Keyword.get(opts, :channel_filter),
      command: Keyword.fetch!(opts, :command),
      enabled: Keyword.get(opts, :enabled, true),
      position: Keyword.get(opts, :position, 0)
    }
  end
end
