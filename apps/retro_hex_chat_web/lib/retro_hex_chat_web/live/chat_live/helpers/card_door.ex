defmodule RetroHexChatWeb.ChatLive.Helpers.CardDoor do
  @moduledoc """
  Putting a room's card where the reader is.

  Every room in this product has one door and it is a card in the conversation —
  a conference, a space, a P2P session. The control beside the tabs writes that
  card; what it used to do on a second press was answer "its card is in this
  conversation" and write nothing, which reads as a refusal to anybody who
  pressed precisely because they could not find it. Scrolling a busy channel
  looking for a card is the work the control exists to save.

  So a press always brings the card down to the bottom, which is where the
  reader already is. The one press that writes nothing is the one where the card
  is *already* the last line: there is nothing to bring down, and a second
  identical card is the only thing a double click could produce.

  Written once for every kind of card. The rule spelled out per room is the rule
  three rooms end up disagreeing about, and this one is the difference between a
  control that behaves and three that each behave a little differently.
  """

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Service, as: ChatService

  @typedoc "Whether the press put a card in the conversation, or found one there."
  @type outcome :: :posted | :already_there

  @doc """
  Writes `line` into `conversation` unless its newest line already carries
  `reference`.

  `reference` is the address the card is drawn from — `/join/<slug>` for a
  minted link, `/p2p/<token>` for a session that is its own invitation — and
  never the whole line, because the sentence around an address is free to change
  and the address is what identifies the card.

  Best effort, like every other line this product writes about itself: a card
  that failed to persist is a smaller failure than a press that raised.
  """
  @spec deliver(Queries.conversation(), String.t(), String.t(), keyword()) :: outcome()
  def deliver(conversation, reference, line, opts \\ [])

  def deliver(conversation, reference, line, opts)
      when is_binary(reference) and is_binary(line) do
    if Queries.newest_line_carries?(conversation, reference) do
      :already_there
    else
      write(conversation, line, Keyword.get(opts, :type, "system"))
      :posted
    end
  end

  defp write({:channel, channel}, line, _type) do
    _written = ChatService.send_system_message(channel, line)
    :ok
  end

  defp write({:pm, from, to}, line, type) do
    _written = ChatService.send_private_message(from, to, line, type)
    :ok
  end
end
