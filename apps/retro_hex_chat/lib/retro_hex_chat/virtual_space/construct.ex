defmodule RetroHexChat.VirtualSpace.Construct do
  @moduledoc """
  The Construct: the empty room every space has behind its gate, built by the
  people who go in.

  A channel's space and a private space each own exactly one Construct, and its
  id is the owner's id behind a prefix — `construct:#lobby`,
  `construct:dm:alice:bob`. Reading the owner back off the id is what lets the
  Construct borrow everything it does not have of its own: who may enter it is
  who may enter the space it belongs to, and a line said inside goes to the same
  conversation.

  A Construct of a Construct is not a thing; the prefix is read once.
  """

  @prefix "construct:"

  @doc "The Construct behind a space's gate."
  @spec space_id(String.t()) :: String.t()
  def space_id(parent_id) when is_binary(parent_id), do: @prefix <> parent_id

  @doc "The space a Construct belongs to, or `:error` for an id that is not one."
  @spec parent_id(term()) :: {:ok, String.t()} | :error
  def parent_id(@prefix <> "#" <> channel) when channel != "", do: {:ok, "#" <> channel}
  def parent_id(@prefix <> "dm:" <> pair) when pair != "", do: {:ok, "dm:" <> pair}
  def parent_id(_space_id), do: :error

  @doc "Whether an id names a Construct."
  @spec construct?(term()) :: boolean()
  def construct?(space_id), do: match?({:ok, _parent}, parent_id(space_id))
end
