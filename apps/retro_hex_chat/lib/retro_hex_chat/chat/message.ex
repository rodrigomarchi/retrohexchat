defmodule RetroHexChat.Chat.Message do
  @moduledoc """
  Ecto schema for channel messages.

  A channel message is addressed to a room, so its scope is the channel name
  plus whoever wrote it. The content rules it shares with every other written
  message live in `RetroHexChat.Chat.MessageRules`; what is declared here is
  what makes this kind of message its own — where it is addressed, and the types
  a room can carry.
  """
  use Ecto.Schema

  alias RetroHexChat.Chat.Attachment
  alias RetroHexChat.Chat.MessageRules

  @type t :: %__MODULE__{}

  # `service`, `error` and `notice` are addressed to a room and have no meaning
  # in a conversation between two people.
  @rules %{
    scope: [channel_name: 50, author_nickname: 16],
    types: ~w(message action system service error notice),
    content_format_constraint: :messages_content_format_check
  }

  schema "messages" do
    field :channel_name, :string
    field :author_nickname, :string
    field :content, :string
    field :content_format, :string, default: "irc"
    field :plain_content, :string
    field :type, :string, default: "message"
    field :allow_blank_content, :boolean, virtual: true, default: false

    field :reply_to_id, :integer
    field :reply_to_author, :string
    field :reply_to_preview, :string
    field :edited_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec

    has_many :attachments, Attachment

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs), do: MessageRules.changeset(message, attrs, @rules)

  @spec reply_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def reply_changeset(message, attrs), do: MessageRules.reply_changeset(message, attrs, @rules)

  @spec edit_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(message, attrs), do: MessageRules.edit_changeset(message, attrs, @rules)

  @spec delete_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(message, attrs), do: MessageRules.delete_changeset(message, attrs)
end
