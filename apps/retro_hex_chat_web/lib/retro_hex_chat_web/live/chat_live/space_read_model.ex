defmodule RetroHexChatWeb.ChatLive.SpaceReadModel do
  @moduledoc """
  What the chat knows about a space it is not inside.

  The same rule that sorted the conference sorts this: if the datum exists for
  someone who is only looking at the conversation, it belongs to the chat; if it
  only exists while you are standing in the space, it belongs to the space's own
  surface. What the chat is left with is one fact — this conversation has a
  space — and it draws a tab from it.

  Everything else went: the avatar roster, the chosen character, the join token
  and the element id are all things that exist only after you walk in.

  The one exception is the character you picked last time, which the chat keeps
  because it outlives every visit: the space surface is mounted fresh each time
  the tab is opened, so a memory held inside it would be no memory at all.
  """

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.VirtualSpace.DirectMessageSpace

  @doc """
  The space of the conversation in focus, or `nil` when there is none.

  Both kinds of conversation have one and they are keyed differently: a channel
  space by the channel's own name, a private one by its two participants. The
  Status tab is not a conversation, so it has no space.
  """
  @spec conversation_space(Session.t(), boolean()) :: map() | nil
  def conversation_space(session, show_status_tab)

  def conversation_space(_session, true), do: nil

  def conversation_space(%{active_pm: peer} = session, _status) when is_binary(peer) do
    participants = [session.nickname, peer]

    case DirectMessageSpace.normalize_participants(participants) do
      {:ok, [left, right] = participants} ->
        %{
          space_id: DirectMessageSpace.space_id(left, right),
          mode: "direct_message",
          participants: participants
        }

      {:error, :invalid_participants} ->
        nil
    end
  end

  def conversation_space(%{active_channel: channel} = _session, _status)
      when is_binary(channel) do
    %{space_id: channel, mode: "channel", participants: nil}
  end

  def conversation_space(_session, _status), do: nil

  @doc "Whether the conversation in focus has a space, for the tab bar."
  @spec has_space?(Session.t()) :: boolean()
  def has_space?(session), do: conversation_space(session, false) != nil
end
