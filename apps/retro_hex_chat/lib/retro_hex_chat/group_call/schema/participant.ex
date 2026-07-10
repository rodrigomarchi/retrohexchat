defmodule RetroHexChat.GroupCall.Schema.Participant do
  @moduledoc """
  Ecto schema for a registered user joining a group call room.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(invited joining connected reconnecting disconnected left kicked failed)
  @terminal_statuses ~w(left kicked failed)
  @role_values ~w(owner operator half_operator voiced regular bot)

  schema "group_call_participants" do
    field :room_id, :integer
    field :registered_nick_id, :integer
    field :nickname, :string
    field :normalized_nickname, :string
    field :channel_role_snapshot, :string, default: "regular"
    field :status, :string, default: "joining"
    field :peer_ref, :string
    field :media_state, :map, default: %{}
    field :client_info, :map, default: %{}
    field :joined_at, :utc_datetime_usec
    field :connected_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :disconnected_at, :utc_datetime_usec
    field :left_at, :utc_datetime_usec
    field :reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :room_id,
      :registered_nick_id,
      :nickname,
      :normalized_nickname,
      :channel_role_snapshot,
      :status,
      :peer_ref,
      :media_state,
      :client_info,
      :joined_at,
      :connected_at,
      :last_seen_at,
      :disconnected_at,
      :left_at,
      :reason
    ])
    |> put_normalized_nickname()
    |> validate_required([
      :room_id,
      :registered_nick_id,
      :nickname,
      :normalized_nickname,
      :channel_role_snapshot,
      :status
    ])
    |> validate_length(:nickname, max: 16)
    |> validate_length(:normalized_nickname, max: 16)
    |> validate_length(:peer_ref, max: 128)
    |> validate_length(:reason, max: 100)
    |> validate_inclusion(:channel_role_snapshot, @role_values)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:normalized_nickname,
      name: :idx_group_call_participants_active_nick,
      message: "already has an active participant in this room"
    )
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:registered_nick_id)
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :status,
      :peer_ref,
      :media_state,
      :client_info,
      :joined_at,
      :connected_at,
      :last_seen_at,
      :disconnected_at,
      :left_at,
      :reason
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_values)
    |> validate_length(:peer_ref, max: 128)
    |> validate_length(:reason, max: 100)
    |> validate_terminal_fields()
  end

  @spec terminal?(String.t()) :: boolean()
  def terminal?(status), do: status in @terminal_statuses

  @spec status_values() :: [String.t()]
  def status_values, do: @status_values

  @spec terminal_statuses() :: [String.t()]
  def terminal_statuses, do: @terminal_statuses

  @spec role_values() :: [String.t()]
  def role_values, do: @role_values

  defp put_normalized_nickname(changeset) do
    case get_field(changeset, :normalized_nickname) || get_field(changeset, :nickname) do
      nil -> changeset
      nickname -> put_change(changeset, :normalized_nickname, String.downcase(nickname))
    end
  end

  defp validate_terminal_fields(changeset) do
    if get_field(changeset, :status) in @terminal_statuses do
      validate_required(changeset, [:left_at, :reason])
    else
      changeset
    end
  end
end
