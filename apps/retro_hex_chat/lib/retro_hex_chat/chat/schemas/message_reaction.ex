defmodule RetroHexChat.Chat.Schemas.MessageReaction do
  @moduledoc """
  One person's one-emoji answer to one message.

  A channel message and a private message live in two tables because the
  product inherited them that way; a reaction does not repeat that split. The
  row carries two nullable parents and the database refuses any row that fills
  neither or both, so "which conversation was this" stays a fact the schema can
  be asked rather than a second table to keep in step.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "message_reactions" do
    field :message_id, :id
    field :private_message_id, :id
    field :owner_nickname, :string
    field :emoji, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :private_message_id, :owner_nickname, :emoji])
    |> validate_required([:owner_nickname, :emoji])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:emoji, max: 32)
    |> check_constraint(:message_id, name: :message_reactions_one_parent)
    |> unique_constraint([:message_id, :owner_nickname, :emoji],
      name: :message_reactions_channel_unique_index
    )
    |> unique_constraint([:private_message_id, :owner_nickname, :emoji],
      name: :message_reactions_private_unique_index
    )
    |> foreign_key_constraint(:owner_nickname,
      name: :message_reactions_owner_nickname_fkey
    )
  end
end
