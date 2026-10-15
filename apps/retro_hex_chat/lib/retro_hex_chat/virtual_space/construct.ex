defmodule RetroHexChat.VirtualSpace.Construct do
  @moduledoc """
  The rooms every space has behind its gates, built by the people who go in.

  There are three kinds. The **Construct** is an empty white floor; the
  **Office** and the **Game Room** come furnished, and what their people add
  stands among the furniture that is part of them. All are the same thing to
  the runtime — a room anybody inside may build in — and differ only in the map
  they start from.

  A channel's space and a private space each own one room of each kind, and its
  id is the owner's id behind the kind's prefix — `construct:#lobby`,
  `office:dm:alice:bob`, `game_room:#lobby`. Reading the owner back off the id
  is what lets a room borrow everything it does not have of its own: who may
  enter it is who may enter the space it belongs to, and a line said inside
  goes to the same conversation.

  A room of a room is not a thing; the prefix is read once.
  """

  @type kind :: :construct | :office | :game_room

  @kinds [construct: "construct:", office: "office:", game_room: "game_room:"]

  @doc "The kinds of room a space has behind its gates."
  @spec kinds() :: [kind()]
  def kinds, do: Keyword.keys(@kinds)

  @doc "The room of `kind` behind a space's gate."
  @spec space_id(String.t(), kind()) :: String.t()
  def space_id(parent_id, kind \\ :construct) when is_binary(parent_id),
    do: Keyword.fetch!(@kinds, kind) <> parent_id

  @doc "The space a room belongs to, or `:error` for an id that is not one."
  @spec parent_id(term()) :: {:ok, String.t()} | :error
  def parent_id(space_id) do
    case split(space_id) do
      {:ok, _kind, parent} -> {:ok, parent}
      :error -> :error
    end
  end

  @doc "Which kind of room an id names, or `:error` for an id that is not one."
  @spec kind(term()) :: {:ok, kind()} | :error
  def kind(space_id) do
    case split(space_id) do
      {:ok, kind, _parent} -> {:ok, kind}
      :error -> :error
    end
  end

  @doc "The map a room of this id is drawn from."
  @spec map_id(String.t()) :: String.t()
  def map_id(space_id) do
    case kind(space_id) do
      {:ok, kind} -> Atom.to_string(kind)
      :error -> "construct"
    end
  end

  @doc "Whether an id names a room behind a gate."
  @spec construct?(term()) :: boolean()
  def construct?(space_id), do: match?({:ok, _kind, _parent}, split(space_id))

  defp split(space_id) when is_binary(space_id) do
    Enum.find_value(@kinds, :error, fn {kind, prefix} ->
      with true <- String.starts_with?(space_id, prefix),
           parent =
             binary_part(space_id, byte_size(prefix), byte_size(space_id) - byte_size(prefix)),
           true <- space_parent?(parent) do
        {:ok, kind, parent}
      else
        _other -> nil
      end
    end)
  end

  defp split(_space_id), do: :error

  defp space_parent?("#" <> channel), do: channel != ""
  defp space_parent?("dm:" <> pair), do: pair != ""
  defp space_parent?(_other), do: false
end
