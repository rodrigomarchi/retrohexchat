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
end
