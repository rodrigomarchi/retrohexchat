defmodule RetroHexChat.Chat.Message do
  @moduledoc """
  Ecto schema for channel messages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @type_values ~w(message action system service error notice)

  schema "messages" do
    field :channel_name, :string
    field :author_nickname, :string
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
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:channel_name, :author_nickname, :content, :type])
    |> validate_required([:channel_name, :author_nickname, :content])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:author_nickname, max: 16)
    |> validate_inclusion(:type, @type_values)
  end

  @spec reply_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def reply_changeset(message, attrs) do
    message
    |> cast(attrs, [
      :channel_name,
      :author_nickname,
      :content,
      :type,
      :reply_to_id,
      :reply_to_author,
      :reply_to_preview
    ])
    |> validate_required([:channel_name, :author_nickname, :content])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:author_nickname, max: 16)
    |> validate_inclusion(:type, @type_values)
    |> validate_reply_fields()
  end

  @spec edit_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :edited_at])
    |> validate_required([:content, :edited_at])
  end

  @spec delete_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(message, attrs) do
    message
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
