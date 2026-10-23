defmodule RetroHexChat.Chat.MessageParent do
  @moduledoc """
  A row hung off a chat message — a reaction, a saved message — points at a
  channel message or a private one, each through its own foreign key. This is
  the one reading of which.
  """

  alias RetroHexChat.Chat.{Message, PrivateMessage}

  @type kind :: :message | :private_message

  @doc "The kind of message and its id."
  @spec of(Message.t() | PrivateMessage.t()) :: {kind(), integer()}
  def of(%Message{id: id}), do: {:message, id}
  def of(%PrivateMessage{id: id}), do: {:private_message, id}

  @doc "The foreign key a row uses to point at a message of `kind`."
  @spec field(kind()) :: :message_id | :private_message_id
  def field(:message), do: :message_id
  def field(:private_message), do: :private_message_id
end
