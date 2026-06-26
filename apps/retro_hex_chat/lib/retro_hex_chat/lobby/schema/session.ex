defmodule RetroHexChat.Lobby.Schema.Session do
  @moduledoc """
  Ecto schema for `lobby_sessions` — the universal P2P lobby.

  Unlike `RetroHexChat.P2P.Schema.Session`, a lobby session is a single
  *persistent* connection between two registered users that hosts every P2P
  feature (audio, video, file transfer and games) concurrently. The status
  reflects only the connection lifecycle, never which feature is active:

      pending → lobby → connected → (closed | expired | failed)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(pending lobby connected closed expired failed)
  @terminal_statuses ~w(closed expired failed)

  schema "lobby_sessions" do
    field :token, :string
    field :creator_id, :integer
    field :peer_id, :integer
    field :status, :string, default: "pending"
    field :metadata, :map, default: %{}
    field :accepted_at, :utc_datetime_usec
    field :connected_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string
    field :duration_seconds, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :token,
      :creator_id,
      :peer_id,
      :status,
      :metadata,
      :closed_at,
      :closed_reason
    ])
    |> validate_required([:token, :creator_id, :peer_id, :status])
    |> validate_length(:token, max: 64)
    |> validate_length(:closed_reason, max: 100)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:token)
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :closed_at,
      :closed_reason,
      :accepted_at,
      :connected_at,
      :duration_seconds
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_values)
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
