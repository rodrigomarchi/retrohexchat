defmodule RetroHexChat.Channels.Schemas.ChannelEvent do
  @moduledoc """
  Something a channel has agreed to do together, at a time.

  `starts_at` is UTC, like every other timestamp here. A time is the one field
  in this product that people get wrong in both directions — storing a local
  time makes the row lie to everybody who is not the author, and rendering UTC
  makes it lie to everybody including the author — so the split is absolute:
  stored in UTC, drawn in the reader's own zone.

  Cancelling keeps the row. A channel that was going to meet and then did not
  is a fact the channel may want to see, and a deleted row also takes the
  answers people gave with it.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias RetroHexChat.Channels.Schemas.ChannelEventAttendee

  @type t :: %__MODULE__{}

  @title_max 120
  @description_max 500

  schema "channel_events" do
    field :channel_name, :string
    field :title, :string
    field :description, :string
    field :starts_at, :utc_datetime_usec
    field :created_by, :string
    field :surface_hint, :string
    field :announcement_message_id, :integer
    field :cancelled_at, :utc_datetime_usec
    field :reminded_at, :utc_datetime_usec

    has_many :attendees, ChannelEventAttendee, foreign_key: :event_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc "How long a title and a description may be."
  @spec title_max() :: pos_integer()
  def title_max, do: @title_max

  @spec description_max() :: pos_integer()
  def description_max, do: @description_max

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :channel_name,
      :title,
      :description,
      :starts_at,
      :created_by,
      :surface_hint
    ])
    |> validate_required([:channel_name, :title, :starts_at, :created_by])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:title, min: 1, max: @title_max)
    |> validate_length(:description, max: @description_max)
    |> validate_length(:created_by, max: 16)
    |> validate_length(:surface_hint, max: 40)
  end

  @doc "Records the line the channel got, so the card can be drawn under it."
  @spec announcement_changeset(t(), integer()) :: Ecto.Changeset.t()
  def announcement_changeset(event, message_id) do
    change(event, announcement_message_id: message_id)
  end

  @spec cancel_changeset(t(), DateTime.t()) :: Ecto.Changeset.t()
  def cancel_changeset(event, at), do: change(event, cancelled_at: at)
end
