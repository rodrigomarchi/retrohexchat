defmodule RetroHexChat.Arcade.Schema.SoloSession do
  @moduledoc """
  Ecto schema for solo_sessions table.
  Represents a single-player arcade session for one registered user.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  use RetroHexChat.Schema.Lifecycle,
    statuses: ~w(pending lobby playing finished closed expired),
    terminal: ~w(finished closed expired),
    terminal_fields: [:closed_at, :closed_reason]

  schema "solo_sessions" do
    field :token, :string
    field :creator_id, :integer
    field :status, :string, default: "pending"
    field :game_id, :string
    field :metadata, :map, default: %{}
    field :lobby_at, :utc_datetime_usec
    field :game_started_at, :utc_datetime_usec
    field :duration_seconds, :integer
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string
    # The lines that said the game was started, in its channel and in `#arcade`.
    field :channel_message_id, :integer
    field :feed_message_id, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec message_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def message_changeset(session, attrs),
    do: cast(session, attrs, [:channel_message_id, :feed_message_id])

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :token,
      :creator_id,
      :status,
      :game_id,
      :metadata,
      :lobby_at,
      :game_started_at,
      :duration_seconds,
      :closed_at,
      :closed_reason
    ])
    |> validate_required([:token, :creator_id, :status])
    |> validate_length(:token, max: 64)
    |> validate_length(:game_id, max: 30)
    |> validate_length(:closed_reason, max: 100)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:token)
  end

  @spec status_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def status_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :game_id,
      :metadata,
      :lobby_at,
      :game_started_at,
      :duration_seconds,
      :closed_at,
      :closed_reason
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_values)
    |> validate_terminal_fields()
  end
end
