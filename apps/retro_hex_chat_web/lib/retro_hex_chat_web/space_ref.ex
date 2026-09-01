defmodule RetroHexChatWeb.SpaceRef do
  @moduledoc """
  How a space's id travels through a URL and through the DOM.

  A space is a place rather than an event, so its address is its own id and not
  a token minted for one visit. That id is either a channel name or a private
  space's key, and both carry characters a path segment should not: `#` is a
  fragment delimiter, and a channel name a stranger reads off an address bar
  names a channel they may not be allowed to know exists.

  So the slug is the id, encoded. The same encoding already names the element
  the space renders into, and that name is a contract with `SpaceCanvasHook`
  and with four Playwright specs — writing it twice is how the two would drift.

  This is an encoding and never a secret: decoding it is trivial and is meant
  to be. What keeps someone out of a space is the policy the surface applies to
  whoever followed the address, which is decision D1 of the plan and is
  unchanged by how the address is spelled.

  **Readable is the decision, not the leftover.** An audit asked for an opaque
  id instead, because `/space/<base64(#channel)>` names the channel to anyone
  who runs one command, and that is true. The price of an opaque one is a table,
  a migration, every link already shared going dead, and a new contract to keep
  in step with `SpaceCanvasHook` and four Playwright specs — for a leak that
  exists only for a private channel and that the refusal already stopped putting
  on screen. The trade was weighed and refused; if it is ever reopened, it is
  that cost that has to have changed, not this sentence.
  """

  alias RetroHexChat.VirtualSpace

  @doc "The path segment a space is addressed by."
  @spec slug(String.t()) :: String.t()
  def slug(space_id) when is_binary(space_id), do: Base.url_encode64(space_id, padding: false)

  @doc """
  The space a slug names, or `:error` when it names nothing this app can serve.

  A decoded id has to look like one of the two shapes a space id takes;
  anything else is a slug somebody typed or truncated, and answering it with a
  space would be answering a question nobody asked.
  """
  @spec space_id(term()) :: {:ok, String.t()} | :error
  def space_id(slug) when is_binary(slug) do
    with {:ok, decoded} <- Base.url_decode64(slug, padding: false),
         true <- String.valid?(decoded),
         true <- known_shape?(decoded) do
      {:ok, decoded}
    else
      _unreadable -> :error
    end
  end

  def space_id(_slug), do: :error

  @doc """
  The id of the element the space renders into.

  A contract with the canvas hook and with the specs that drive it, which is
  why it is derived here and not spelled out at the call site.
  """
  @spec dom_id(String.t()) :: String.t()
  def dom_id(space_id) when is_binary(space_id), do: "conversation-space-" <> slug(space_id)

  defp known_shape?("#" <> rest), do: rest != ""

  defp known_shape?(space_id) do
    VirtualSpace.space_kind(space_id) == :direct_message and
      match?({:ok, [_a, _b]}, participants(space_id))
  end

  @doc """
  The two nicknames a private space's id is built from.

  A private space has no membership record: it is keyed by the pair, so the id
  is the membership. Recovering the pair from the address is what lets a tab
  opened cold say whether the person holding it is one of the two.
  """
  @spec participants(String.t()) :: {:ok, [String.t()]} | :error
  def participants("dm:" <> pair) do
    case String.split(pair, ":") do
      [left, right] when left != "" and right != "" -> {:ok, [left, right]}
      _malformed -> :error
    end
  end

  def participants(_space_id), do: :error
end
