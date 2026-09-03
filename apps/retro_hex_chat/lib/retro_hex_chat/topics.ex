defmodule RetroHexChat.Topics do
  @moduledoc """
  The PubSub topics a conversation is delivered on.

  Two kinds of conversation exist and they are addressed differently, which is
  the one difference worth naming: a channel has a topic that everyone in it
  joins, while a private conversation has no join at all — it is created by its
  first message. A person's inbox is what stands in for the join: it is
  subscribed once, at mount, and stays subscribed, so the first message of a
  conversation arrives by the same route as the thousandth.

  These names were interpolated at each call site, which is how the same topic
  came to be built by three separate copies of the same sort-and-join.

  `:` separates every part of every name here, and nothing escapes it. That is
  safe only because `Accounts.NicknameValidator` forbids `:` in a nickname —
  otherwise a person called `alice:surfaces` would share a topic with alice's
  surfaces. Widening the nickname charset means revisiting this file.
  """

  @doc "Everything addressed to one person, whichever conversation it belongs to."
  @spec inbox(String.t()) :: String.t()
  def inbox(nickname) when is_binary(nickname), do: "user:" <> nickname

  @doc "Everything addressed to a channel."
  @spec channel(String.t()) :: String.t()
  def channel(name) when is_binary(name), do: "channel:" <> name

  @doc """
  A channel's call lifecycle, apart from its conversation.

  Starting, ending, a roster change and a moderation act are the only things
  published here, and two very different readers want exactly them: the chat,
  which draws a badge for a call it is not in, and the call's own surface,
  which draws the roster in its antechamber. Putting them on the channel's
  conversation topic would hand every message in a busy channel to a process
  that only ever wanted to know who is in the room.
  """
  @spec channel_calls(String.t()) :: String.t()
  def channel_calls(name) when is_binary(name), do: channel(name) <> ":calls"

  @doc """
  One P2P session's wire: every ICE candidate and every SDP crosses here, so a
  screen that only wants to know that a session changed state must not listen
  to it — the session tells its participants on their own `inbox/1` instead.
  """
  @spec lobby(String.t()) :: String.t()
  def lobby(session_token) when is_binary(session_token), do: "lobby:" <> session_token

  @doc "Everything a virtual space pushes to the clients standing in it."
  @spec space(String.t()) :: String.t()
  def space(space_id) when is_binary(space_id), do: "space:" <> space_id

  @doc """
  Who is in a space, apart from everything else the space says.

  The space topic carries a movement delta for every step every character
  takes. Two readers want none of that and only the list of names: the
  antechamber, which draws who is already inside before you walk in, and the
  chat, which draws the same list on the card in the conversation. Subscribing
  either of them to the space itself would hand a walking-simulator's worth of
  messages to a process that renders a list of nicknames.
  """
  @spec space_roster(String.t()) :: String.t()
  def space_roster(space_id) when is_binary(space_id), do: space(space_id) <> ":roster"

  @doc """
  Where a person is tracked for as long as they are connected, whatever they are
  looking at.

  A channel's presence topic only knows the people who joined it, which is the
  wrong question for anything that has to answer "is this person here" about
  someone you share no channel with — a private conversation, a whois, a hover
  card.
  """
  @spec presence() :: String.t()
  def presence, do: "presence:global"

  @doc """
  Where a person's non-chat surfaces listen, and only for the end of their own
  session.

  A call, a space or a game can live in a browser tab of its own, beside the
  chat. Those surfaces must survive the chat being taken over by another tab and
  must not survive a ban, so they cannot listen on the inbox: the inbox carries
  both meanings on the same message. This topic carries only the second, which
  is why a surface subscribed here needs no clause that ignores a private
  message.
  """
  @spec surfaces(String.t()) :: String.t()
  def surfaces(nickname) when is_binary(nickname), do: inbox(nickname) <> ":surfaces"

  @doc """
  What this person currently has open, for the one screen that has to draw the
  difference between opening a thing and going back to it.

  A separate topic from `surfaces/1` and not a second meaning on it: that one is
  read by every satellite and carries only the end of the session, and a roster
  of open tabs arriving there would need a clause in each surface that ignores
  it. One publisher (`RetroHexChat.Surfaces`); the subscribers are the screens
  that draw a way in — the chat, and the two surfaces the chat also renders
  inside itself, all through `Live.OpenSurfaces`.
  """
  @spec surfaces_open(String.t()) :: String.t()
  def surfaces_open(nickname) when is_binary(nickname), do: surfaces(nickname) <> ":open"
end
