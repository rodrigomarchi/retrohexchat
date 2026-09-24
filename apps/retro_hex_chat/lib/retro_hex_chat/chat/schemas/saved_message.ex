defmodule RetroHexChat.Chat.Schemas.SavedMessage do
  @moduledoc """
  One line one person decided to come back to.

  Channel messages and private messages live in two tables because the product
  inherited them that way; what somebody kept does not repeat that split. The
  row carries two nullable parents and the database refuses any row that fills
  neither or both, so "which conversation was this" stays a fact the schema can
  be asked.

  The owner is a registered nickname and nothing else. A list that survives the
  scrollback has to survive a disconnect, and only a registered nick is still
  the same person tomorrow.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "saved_messages" do
    field :message_id, :id
    field :private_message_id, :id
    field :owner_nickname, :string
    field :note, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(saved, attrs) do
    saved
    |> cast(attrs, [:message_id, :private_message_id, :owner_nickname, :note])
    |> validate_required([:owner_nickname])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:note, max: 200)
    |> check_constraint(:message_id, name: :saved_messages_one_parent)
    |> unique_constraint([:owner_nickname, :message_id],
      name: :saved_messages_channel_unique_index
    )
    |> unique_constraint([:owner_nickname, :private_message_id],
      name: :saved_messages_private_unique_index
    )
    |> foreign_key_constraint(:owner_nickname, name: :saved_messages_owner_nickname_fkey)
  end
end
