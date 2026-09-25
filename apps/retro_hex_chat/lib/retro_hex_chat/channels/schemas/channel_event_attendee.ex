defmodule RetroHexChat.Channels.Schemas.ChannelEventAttendee do
  @moduledoc """
  One person saying they will be there.

  The only answer there is. "Maybe" is a word people use to avoid saying no, and
  a list that carries it tells the organiser nothing it did not already know.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias RetroHexChat.Channels.Schemas.ChannelEvent

  @type t :: %__MODULE__{}

  schema "channel_event_attendees" do
    belongs_to :event, ChannelEvent
    field :nickname, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:event_id, :nickname])
    |> validate_required([:event_id, :nickname])
    |> validate_length(:nickname, max: 16)
    |> unique_constraint([:event_id, :nickname],
      name: :channel_event_attendees_event_id_nickname_index
    )
    |> foreign_key_constraint(:event_id)
  end
end
