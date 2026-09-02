defmodule RetroHexChat.VirtualSpace.Schema.Session do
  @moduledoc """
  One gathering in a space, from the moment somebody walked into an empty one
  until the moment the last of them left.

  A space is a place and its address stays good forever, which is why the space
  itself is not a row and never was. What ends is the gathering: people arrive,
  the world starts, they leave, the world stops. That is the thing a card in the
  conversation can be about — "somebody is in the space" while it runs, and
  "they were in there for eleven minutes, five of them" once it is over.

  The row's life is the runtime process's life, watched by a monitor rather than
  written from inside the space. A world that crashes has to count exactly as
  one that emptied, and `terminate/2` is the one callback that does not run when
  it matters.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @status_values ~w(open closed expired)
  @terminal_statuses ~w(closed expired)
  @kinds ~w(channel direct_message)

  schema "virtual_space_sessions" do
    field :token, :string
    field :space_id, :string
    field :kind, :string
    field :status, :string, default: "open"
    field :opened_by, :integer
    field :opened_by_nick, :string
    field :opened_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :token,
      :space_id,
      :kind,
      :status,
      :opened_by,
      :opened_by_nick,
      :opened_at,
      :closed_at,
      :closed_reason
    ])
    |> validate_required([:token, :space_id, :kind, :status, :opened_by_nick])
    |> validate_length(:token, max: 64)
    |> validate_length(:space_id, max: 100)
    |> validate_length(:opened_by_nick, max: 16)
    |> validate_length(:closed_reason, max: 100)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:token)
    |> unique_constraint(:space_id,
      name: :idx_virtual_space_sessions_one_open_per_space,
      message: "already has an open session"
    )
  end

  @spec close_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def close_changeset(session, attrs) do
    session
    |> cast(attrs, [:status, :closed_at, :closed_reason])
    |> validate_required([:status, :closed_at])
    |> validate_inclusion(:status, @terminal_statuses)
    |> validate_length(:closed_reason, max: 100)
  end

  @spec terminal?(String.t()) :: boolean()
  def terminal?(status), do: status in @terminal_statuses

  @spec terminal_statuses() :: [String.t()]
  def terminal_statuses, do: @terminal_statuses
end
