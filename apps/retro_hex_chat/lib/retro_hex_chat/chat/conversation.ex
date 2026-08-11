defmodule RetroHexChat.Chat.Conversation do
  @moduledoc """
  Where a message goes, and how a reader tells which conversation it came from.

  A channel and a private conversation are the same idea addressed two ways, and
  this is the whole of the difference. A channel is a name everybody in it
  joined, so it has one topic. A private conversation has no join — it is created
  by its first message — so it is delivered to each of its two people's inboxes.

  Alongside the destination goes the field that identifies the conversation in a
  payload, because the two kinds share event names: `message_edited` from a
  channel names the channel, and from a private conversation names a
  participant. A reader keyed on which of the two is present, and that only
  works if one place decides it.
  """

  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage
  alias RetroHexChat.Topics

  @typedoc "A message somebody wrote, in whichever kind of conversation."
  @type message :: Message.t() | PrivateMessage.t()

  @doc "Every topic a message about this conversation has to be published on."
  @spec topics(message()) :: [String.t()]
  def topics(%Message{channel_name: name}), do: [Topics.channel(name)]

  def topics(%PrivateMessage{sender_nickname: sender, recipient_nickname: recipient}),
    do: [Topics.inbox(sender), Topics.inbox(recipient)]

  @doc "The field a payload carries so a reader knows which conversation it is."
  @spec address(message()) :: map()
  def address(%Message{channel_name: name}), do: %{channel: name}
  def address(%PrivateMessage{sender_nickname: sender}), do: %{sender: sender}
end
