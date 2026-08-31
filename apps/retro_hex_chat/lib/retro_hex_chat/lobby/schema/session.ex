defmodule RetroHexChat.Lobby.Schema.Session do
  @moduledoc """
  Ecto schema for `lobby_sessions` — the P2P lobby.

  A lobby session is a single *persistent* connection between two registered
  users that hosts every P2P feature (audio, video, file transfer and games)
  concurrently. The status
  reflects only the connection lifecycle, never which feature is active:

      open → pending → lobby → connected → (closed | expired | failed)

  `open` is a session that has a creator and no peer yet — a match link posted
  somewhere, waiting for whoever follows it. It is the one status in which
  `peer_id` may be null, and taking that seat is a single conditional write
  (`Lobby.Queries.claim_open_session/2`), never a read followed by a write.
  Because an open lobby is an invitation rather than an address, it carries an
  `expires_at` and dies on its own if nobody claims it.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(open pending lobby connected closed expired failed)
  @terminal_statuses ~w(closed expired failed)
  # The statuses in which a session is a connection between two people. `open`
  # has no peer yet and a terminal one never will: a match link nobody claimed
  # still has to be closeable, and demanding a peer to write `expired` would
  # make the sweep unable to bury exactly the rows it exists for.
  @paired_statuses ~w(pending lobby connected)

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
    field :expires_at, :utc_datetime_usec

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
      :closed_reason,
      :expires_at
    ])
    |> validate_required([:token, :creator_id, :status])
    |> validate_peer_for_status()
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
    |> validate_peer_for_status()
    |> validate_terminal_fields()
  end

  @spec open?(String.t()) :: boolean()
  def open?(status), do: status == "open"

  @spec terminal?(String.t()) :: boolean()
  def terminal?(status), do: status in @terminal_statuses

  @spec status_values() :: [String.t()]
  def status_values, do: @status_values

  # The invariant that used to be "there are always two of you". It guards the
  # status changeset as well as creation, because otherwise a plain status
  # write could walk a peerless session into `pending` without ever touching
  # `peer_id` — the invariant belongs to the pair of fields, not to one write.
  defp validate_peer_for_status(changeset) do
    if get_field(changeset, :status) in @paired_statuses do
      validate_required(changeset, [:peer_id])
    else
      changeset
    end
  end

  defp validate_terminal_fields(changeset) do
    status = get_field(changeset, :status)

    if status in @terminal_statuses do
      validate_required(changeset, [:closed_at, :closed_reason])
    else
      changeset
    end
  end
end
