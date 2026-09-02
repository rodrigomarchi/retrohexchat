defmodule RetroHexChat.VirtualSpace.Schema.Participant do
  @moduledoc """
  Somebody who was in a space while one gathering lasted.

  One row per nickname per gathering, stamped when they walk in. There is no
  departure, because there is nothing to read one from: a channel space draws
  every member of the channel on its map, and somebody closing the tab is a
  viewer count going down with no nickname attached to it. Re-entering does not
  make a second row either — the question the ended card asks is how many people
  came, and somebody who stepped out for a moment is not two of them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.VirtualSpace.Schema.Session

  @type t :: %__MODULE__{}

  schema "virtual_space_session_participants" do
    belongs_to :session, Session
    field :nickname, :string
    field :normalized_nickname, :string
    field :joined_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :session_id,
      :nickname,
      :normalized_nickname,
      :joined_at
    ])
    |> validate_required([:session_id, :nickname, :normalized_nickname])
    |> validate_length(:nickname, max: 16)
    |> validate_length(:normalized_nickname, max: 16)
    |> unique_constraint([:session_id, :normalized_nickname],
      name: :idx_virtual_space_participants_once,
      message: "is already in this session"
    )
  end
end
