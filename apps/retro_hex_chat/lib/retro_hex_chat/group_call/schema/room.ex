defmodule RetroHexChat.GroupCall.Schema.Room do
  @moduledoc """
  Ecto schema for channel-scoped group call rooms.

  A room is the durable product record for one embedded SFU call. Runtime media
  forwarding will live in OTP processes; this schema records lifecycle events
  only.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(pending open active closing closed expired failed)
  @terminal_statuses ~w(closed expired failed)

  schema "group_call_rooms" do
    field :token, :string
    field :channel_name, :string
    field :creator_id, :integer
    field :creator_nick, :string
    field :title, :string
    field :status, :string, default: "pending"
    field :max_participants, :integer, default: 100
    field :media_policy, :map, default: %{}
    field :codec_policy, :map, default: %{}
    field :ice_policy, :map, default: %{}
    field :metadata, :map, default: %{}
    field :opened_at, :utc_datetime_usec
    field :activated_at, :utc_datetime_usec
    field :last_activity_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(room, attrs) do
    room
    |> cast(attrs, [
      :token,
      :channel_name,
      :creator_id,
      :creator_nick,
      :title,
      :status,
      :max_participants,
      :media_policy,
      :codec_policy,
      :ice_policy,
      :metadata,
      :opened_at,
      :activated_at,
      :last_activity_at,
      :expires_at,
      :closed_at,
      :closed_reason
    ])
    |> validate_required([:token, :channel_name, :creator_id, :creator_nick, :status])
    |> validate_length(:token, max: 64)
    |> validate_length(:channel_name, max: 100)
    |> validate_length(:creator_nick, max: 16)
    |> validate_length(:title, max: 100)
    |> validate_length(:closed_reason, max: 100)
    |> validate_number(:max_participants, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:token)
    |> unique_constraint(:channel_name,
      name: :idx_group_call_rooms_one_active_per_channel,
      message: "already has an active group call"
    )
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(room, attrs) do
    room
    |> cast(attrs, [
      :status,
      :opened_at,
      :activated_at,
      :last_activity_at,
      :expires_at,
      :closed_at,
      :closed_reason,
      :metadata
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_values)
    |> validate_length(:closed_reason, max: 100)
    |> validate_terminal_fields()
  end

  @spec terminal?(String.t()) :: boolean()
  def terminal?(status), do: status in @terminal_statuses

  @spec status_values() :: [String.t()]
  def status_values, do: @status_values

  @spec terminal_statuses() :: [String.t()]
  def terminal_statuses, do: @terminal_statuses

  defp validate_terminal_fields(changeset) do
    if get_field(changeset, :status) in @terminal_statuses do
      validate_required(changeset, [:closed_at, :closed_reason])
    else
      changeset
    end
  end
end
