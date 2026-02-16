defmodule RetroHexChat.P2P.Schema.Session do
  @moduledoc """
  Ecto schema for p2p_sessions table.
  Represents a peer-to-peer session between two registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(pending lobby connecting active closed expired failed)
  @session_type_values ~w(generic file_transfer audio_call video_call)
  @terminal_statuses ~w(closed expired failed)

  schema "p2p_sessions" do
    field :token, :string
    field :creator_id, :integer
    field :peer_id, :integer
    field :status, :string, default: "pending"
    field :session_type, :string, default: "generic"
    field :metadata, :map, default: %{}
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string

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
      :session_type,
      :metadata,
      :closed_at,
      :closed_reason
    ])
    |> validate_required([:token, :creator_id, :peer_id, :status, :session_type])
    |> validate_length(:token, max: 64)
    |> validate_length(:closed_reason, max: 100)
    |> validate_inclusion(:status, @status_values)
    |> validate_inclusion(:session_type, @session_type_values)
    |> unique_constraint(:token)
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(session, attrs) do
    session
    |> cast(attrs, [:status, :closed_at, :closed_reason])
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
      changeset
      |> validate_required([:closed_at, :closed_reason])
    else
      changeset
    end
  end
end
