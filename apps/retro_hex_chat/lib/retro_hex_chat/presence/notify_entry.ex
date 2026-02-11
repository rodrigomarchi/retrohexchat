defmodule RetroHexChat.Presence.NotifyEntry do
  @moduledoc """
  In-memory runtime struct for a single notify list entry.
  The `online` field is computed at runtime from global presence events.
  """

  @type t :: %__MODULE__{
          tracked_nickname: String.t(),
          note: String.t() | nil,
          last_seen_at: DateTime.t() | nil,
          online: boolean()
        }

  @enforce_keys [:tracked_nickname]
  defstruct [
    :tracked_nickname,
    :note,
    :last_seen_at,
    online: false
  ]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end
end
