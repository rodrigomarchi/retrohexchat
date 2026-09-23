defmodule RetroHexChat.Channels.Schemas.PinnedMessage do
  @moduledoc """
  One line a channel is keeping in view.

  The row carries who pinned it and when; everything the pin displays comes from
  the message it points at, which is why the foreign key cascades — a pin whose
  line was deleted has nothing left to show.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "pinned_messages" do
    field :channel_name, :string
    field :message_id, :integer
    field :pinned_by, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(pin, attrs) do
    pin
    |> cast(attrs, [:channel_name, :message_id, :pinned_by])
    |> validate_required([:channel_name, :message_id, :pinned_by])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:pinned_by, max: 16)
    |> unique_constraint([:channel_name, :message_id],
      name: :pinned_messages_channel_name_message_id_index
    )
    |> foreign_key_constraint(:message_id)
  end
end
