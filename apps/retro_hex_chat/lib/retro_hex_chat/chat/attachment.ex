defmodule RetroHexChat.Chat.Attachment do
  @moduledoc """
  Link between an uploaded file and a chat message.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Chat.{Message, PrivateMessage, UploadedFile}

  @type t :: %__MODULE__{}

  schema "chat_attachments" do
    field :display_filename, :string
    field :position, :integer, default: 0

    belongs_to :file, UploadedFile
    belongs_to :message, Message
    belongs_to :private_message, PrivateMessage

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :file_id,
      :display_filename,
      :position,
      :message_id,
      :private_message_id
    ])
    |> validate_required([:file_id, :display_filename, :position])
    |> validate_length(:display_filename, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:file_id)
    |> foreign_key_constraint(:message_id)
    |> foreign_key_constraint(:private_message_id)
    |> check_constraint(:message_id, name: :chat_attachments_one_message_target)
    |> check_constraint(:position, name: :chat_attachments_position_non_negative)
    |> unique_constraint([:message_id, :file_id])
    |> unique_constraint([:private_message_id, :file_id])
  end
end
