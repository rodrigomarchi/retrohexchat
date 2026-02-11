defmodule RetroHexChat.Chat.IgnoreEntry do
  @moduledoc """
  In-memory runtime struct for a single ignore list entry.
  Tracks which user is ignored, the ignore type, and optional expiration.
  """

  @type t :: %__MODULE__{
          nickname: String.t(),
          ignore_type: :all | :messages | :pms | :invites | :actions,
          expires_at: DateTime.t() | nil,
          created_at: DateTime.t()
        }

  @valid_types [:all, :messages, :pms, :invites, :actions]

  @enforce_keys [:nickname, :ignore_type, :created_at]
  defstruct [
    :nickname,
    :ignore_type,
    :expires_at,
    :created_at
  ]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.to_list(attrs))
  end

  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @spec permanent?(t()) :: boolean()
  def permanent?(%__MODULE__{expires_at: nil}), do: true
  def permanent?(%__MODULE__{}), do: false

  @spec remaining_seconds(t()) :: non_neg_integer()
  def remaining_seconds(%__MODULE__{expires_at: nil}), do: 0

  def remaining_seconds(%__MODULE__{expires_at: expires_at}) do
    diff = DateTime.diff(expires_at, DateTime.utc_now(), :second)
    max(diff, 0)
  end

  @spec valid_type?(atom()) :: boolean()
  def valid_type?(type), do: type in @valid_types

  @spec valid_types() :: [atom()]
  def valid_types, do: @valid_types
end
