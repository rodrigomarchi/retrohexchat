defmodule RetroHexChatWeb.Components.UI.Chat.Role do
  @moduledoc """
  Reducing the many spellings of a channel role to the one the UI groups by.

  A role reaches a nicklist from several directions — an atom from channel
  state, a string from a stored preference, an IRC-flavoured abbreviation like
  `"op"` or `"half-op"` — and every screen that sorts, counts or colours users
  has to agree on which of those mean the same thing. Disagreeing is not a
  visual defect but a structural one: two lists of the same channel would put
  the same person in different sections.

  Anything unrecognised reads as a regular user, so an unknown role degrades to
  the least privilege rather than raising in a render.
  """

  @type t :: :owner | :operator | :half_operator | :voiced | :bot | :regular

  @doc "The canonical role for any spelling of one."
  @spec key(term()) :: t()
  def key(:normal), do: :regular
  def key(:owner), do: :owner
  def key(:operator), do: :operator
  def key(:half_operator), do: :half_operator
  def key(:voiced), do: :voiced
  def key(:bot), do: :bot
  def key(:regular), do: :regular
  def key("owner"), do: :owner
  def key("op"), do: :operator
  def key("operator"), do: :operator
  def key("half_operator"), do: :half_operator
  def key("half-op"), do: :half_operator
  def key("voice"), do: :voiced
  def key("voiced"), do: :voiced
  def key("bot"), do: :bot
  def key(_role), do: :regular

  @doc """
  The canonical role as a hyphenated token, for a CSS class or a DOM id.
  """
  @spec slug(term()) :: String.t()
  def slug(role) do
    role
    |> key()
    |> Atom.to_string()
    |> String.replace("_", "-")
  end
end
