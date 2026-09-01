defmodule RetroHexChatWeb.ChatLive.ShareCards do
  @moduledoc """
  Keeping the cards in the conversation current, and paying for it only while
  one is on screen.

  A card is the room it names *right now*, so something has to tell it when the
  room changed. Two of the three kinds cost nothing new: the chat already hears
  a channel's conference broadcasts, and it already knows the P2P sessions it is
  part of. The space is the one that would be expensive — every step of every
  avatar is a roster message — so the chat subscribes to a space's roster
  **only while a card for it is being rendered**, and drops the subscription
  when the last one scrolls out of the held window.

  That is the whole reason this module exists rather than a `subscribe` next to
  the others at mount: a subscription that outlives the reason for it turns a
  conversation into a firehose for somebody who only wanted to read.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.Nicklist
  alias RetroHexChatWeb.ChatLive.GroupCallReadModel

  @pubsub RetroHexChat.PubSub

  @doc """
  Ask the two readers of a room's state to read it again.

  The card in the conversation and the marker in the user list answer the same
  question about the same summary, so they are refreshed together — separating
  them is how one of them comes to be right and the other stale.
  """
  @spec refresh(Socket.t()) :: Socket.t()
  def refresh(socket) do
    send_update(MessageViewport, id: MessageViewport.id(), action: :refresh_share_cards)
    mark_nicklist(socket)
  end

  defp mark_nicklist(%{assigns: %{session: %{active_channel: channel}}} = socket)
       when is_binary(channel) do
    Nicklist.mark_in_call(socket, GroupCallReadModel.participants(socket, channel))
  end

  defp mark_nicklist(socket), do: Nicklist.mark_in_call(socket, [])

  @doc """
  Follow exactly the spaces that have a card on screen.

  Takes the whole set rather than a delta: the viewport knows what it is
  showing, and a delta would make this the second place that has to be right
  about which cards exist.
  """
  @spec watch_spaces(Socket.t(), MapSet.t(String.t())) :: Socket.t()
  def watch_spaces(socket, %MapSet{} = wanted) do
    current = socket.assigns[:share_card_spaces] || MapSet.new()

    Enum.each(MapSet.difference(wanted, current), &Phoenix.PubSub.subscribe(@pubsub, topic(&1)))
    Enum.each(MapSet.difference(current, wanted), &Phoenix.PubSub.unsubscribe(@pubsub, topic(&1)))

    assign(socket, share_card_spaces: wanted)
  end

  def watch_spaces(socket, _wanted), do: socket

  @doc """
  The two messages this module owns.

  `{:share_card_spaces, set}` is the viewport saying what it is rendering; the
  roster broadcast is a space saying somebody moved. Both end in the same
  place, which is the viewport re-reading the rooms.
  """
  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_info({:share_card_spaces, %MapSet{} = spaces}, socket) do
    {:halt, socket |> watch_spaces(spaces) |> refresh()}
  end

  def handle_info({:space_roster, _payload}, socket), do: {:halt, refresh(socket)}

  def handle_info(_message, socket), do: {:cont, socket}

  defp topic(space_id), do: Topics.space_roster(space_id)
end
