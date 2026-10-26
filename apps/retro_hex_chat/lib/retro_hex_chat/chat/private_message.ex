defmodule RetroHexChat.Chat.PrivateMessage do
  @moduledoc """
  Ecto schema for private messages between two users.

  A private message is addressed to a pair rather than a room, so its scope is
  the two nicknames and the sender is the author. The content rules it shares
  with every other written message live in `RetroHexChat.Chat.MessageRules`;
  what is declared here is what makes this kind of message its own — where it is
  addressed, and the types a conversation between two people can carry.
  """
  use Ecto.Schema

  alias RetroHexChat.Chat.MessageRules

  require MessageRules

  @type t :: %__MODULE__{}

  # `p2p_invite` and `p2p_system` are addressed to one other person and have no
  # meaning in a room.
  @rules %{
    scope: [sender_nickname: 16, recipient_nickname: 16],
    types: ~w(message action system p2p_invite p2p_system),
    content_format_constraint: :private_messages_content_format_check
  }

  schema "private_messages" do
    field :sender_nickname, :string
    field :recipient_nickname, :string

    MessageRules.written_fields()
  end

  # ex_dna:disable-for-lines:11 each schema hands its own @rules to MessageRules
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(pm, attrs), do: MessageRules.changeset(pm, attrs, @rules)

  @spec reply_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def reply_changeset(pm, attrs), do: MessageRules.reply_changeset(pm, attrs, @rules)

  @spec edit_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(pm, attrs), do: MessageRules.edit_changeset(pm, attrs, @rules)

  @spec delete_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(pm, attrs), do: MessageRules.delete_changeset(pm, attrs)
end
