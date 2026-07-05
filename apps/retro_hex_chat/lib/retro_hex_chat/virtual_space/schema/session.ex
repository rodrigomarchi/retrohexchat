defmodule RetroHexChat.VirtualSpace.Schema.Session do
  @moduledoc """
  Ecto schema for `virtual_space_sessions` — the multiplayer virtual office.

  A virtual space is created from a channel via `/space`, hosts up to
  `max_participants` users on a tile map and lives until it is closed,
  expires or fails:

      pending → active → (closed | expired | failed)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(pending active closed expired failed)
  @terminal_statuses ~w(closed expired failed)

  schema "virtual_space_sessions" do
    field :token, :string
    field :channel_name, :string
    field :creator_id, :integer
    field :creator_nick, :string
    field :title, :string
    field :status, :string, default: "pending"
    field :map_id, :string, default: "tavern_cafe_v1"
    field :max_participants, :integer, default: 20
    field :last_participant_count, :integer, default: 0
    field :peak_participants, :integer, default: 0
    field :metadata, :map, default: %{}
    field :activated_at, :utc_datetime_usec
    field :last_activity_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :token,
      :channel_name,
      :creator_id,
      :creator_nick,
      :title,
      :status,
      :map_id,
      :max_participants,
      :metadata,
      :expires_at
    ])
    |> validate_required([:token, :channel_name, :creator_id, :creator_nick, :status])
    |> validate_length(:token, max: 64)
    |> validate_length(:channel_name, max: 100)
    |> validate_length(:creator_nick, max: 50)
    |> validate_length(:title, max: 100)
    |> validate_length(:map_id, max: 50)
    |> validate_number(:max_participants, greater_than: 0)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:token)
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :map_id,
      :last_participant_count,
      :peak_participants,
      :metadata,
      :activated_at,
      :last_activity_at,
      :expires_at,
      :closed_at,
      :closed_reason
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

  defp validate_terminal_fields(changeset) do
    status = get_field(changeset, :status)

    if status in @terminal_statuses do
      validate_required(changeset, [:closed_at, :closed_reason])
    else
      changeset
    end
  end
end
