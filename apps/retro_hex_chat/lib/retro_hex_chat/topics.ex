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
  """

  @doc "Everything addressed to one person, whichever conversation it belongs to."
  @spec inbox(String.t()) :: String.t()
  def inbox(nickname) when is_binary(nickname), do: "user:" <> nickname

  @doc "Everything addressed to a channel."
  @spec channel(String.t()) :: String.t()
  def channel(name) when is_binary(name), do: "channel:" <> name
end
