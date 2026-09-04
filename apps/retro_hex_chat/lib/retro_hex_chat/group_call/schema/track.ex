defmodule RetroHexChat.GroupCall.Schema.Track do
  @moduledoc """
  Ecto schema for published media tracks in a group call room.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @kind_values ~w(audio video)
  @status_values ~w(announced active muted ended failed)
  @terminal_statuses ~w(ended failed)

  schema "group_call_tracks" do
    field :room_id, :integer
    field :participant_id, :integer
    field :kind, :string
    field :source, :string
    field :webrtc_track_id, :string
    field :stream_id, :string
    field :mid, :string
    field :rid, :string
    field :status, :string, default: "announced"
    field :codec, :string
    field :metadata, :map, default: %{}
    field :announced_at, :utc_datetime_usec
    field :activated_at, :utc_datetime_usec
    field :muted_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :ended_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(track, attrs) do
    track
    |> cast(attrs, [
      :room_id,
      :participant_id,
      :kind,
      :source,
      :webrtc_track_id,
      :stream_id,
      :mid,
      :rid,
      :status,
      :codec,
      :metadata,
      :announced_at,
      :activated_at,
      :muted_at,
      :ended_at,
      :ended_reason
    ])
    |> validate_required([:room_id, :participant_id, :kind, :source, :webrtc_track_id, :status])
    |> validate_length(:source, max: 30)
    |> validate_length(:webrtc_track_id, max: 128)
    |> validate_length(:stream_id, max: 128)
    |> validate_length(:mid, max: 32)
    |> validate_length(:rid, max: 32)
    |> validate_length(:codec, max: 50)
    |> validate_length(:ended_reason, max: 100)
    |> validate_inclusion(:kind, @kind_values)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:source,
      name: :idx_group_call_tracks_active_source,
      message: "already has an active track for this participant, kind and source"
    )
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:participant_id)
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(track, attrs) do
    track
    |> cast(attrs, [
      :status,
      :codec,
      :metadata,
      :activated_at,
      :muted_at,
      :ended_at,
      :ended_reason
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_values)
    |> validate_length(:codec, max: 50)
    |> validate_length(:ended_reason, max: 100)
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
      validate_required(changeset, [:ended_at, :ended_reason])
    else
      changeset
    end
  end
end
