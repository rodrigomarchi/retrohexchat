defmodule RetroHexChat.Chat.PrivateMessage do
  @moduledoc """
  Ecto schema for private messages between two users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @type_values ~w(message action system p2p_invite)

  schema "private_messages" do
    field :sender_nickname, :string
    field :recipient_nickname, :string
    field :content, :string
    field :type, :string, default: "message"

    field :reply_to_id, :integer
    field :reply_to_author, :string
    field :reply_to_preview, :string
    field :edited_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(pm, attrs) do
    pm
    |> cast(attrs, [:sender_nickname, :recipient_nickname, :content, :type])
    |> validate_required([:sender_nickname, :recipient_nickname, :content])
    |> validate_length(:sender_nickname, max: 16)
    |> validate_length(:recipient_nickname, max: 16)
    |> validate_inclusion(:type, @type_values)
  end

  @spec reply_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def reply_changeset(pm, attrs) do
    pm
    |> cast(attrs, [
      :sender_nickname,
      :recipient_nickname,
      :content,
      :type,
      :reply_to_id,
      :reply_to_author,
      :reply_to_preview
    ])
    |> validate_required([:sender_nickname, :recipient_nickname, :content])
    |> validate_length(:sender_nickname, max: 16)
    |> validate_length(:recipient_nickname, max: 16)
    |> validate_inclusion(:type, @type_values)
    |> validate_reply_fields()
  end

  @spec edit_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(pm, attrs) do
    pm
    |> cast(attrs, [:content, :edited_at])
    |> validate_required([:content, :edited_at])
  end

  @spec delete_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(pm, attrs) do
    pm
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
  end

  defp validate_reply_fields(changeset) do
    reply_to_id = get_change(changeset, :reply_to_id)

    if reply_to_id do
      changeset
      |> validate_required([:reply_to_author, :reply_to_preview])
      |> validate_length(:reply_to_author, max: 16)
      |> validate_length(:reply_to_preview, max: 100)
    else
      changeset
    end
  end
end
