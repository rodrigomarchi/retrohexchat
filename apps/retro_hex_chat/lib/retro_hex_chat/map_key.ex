defmodule RetroHexChat.MapKey do
  @moduledoc """
  A field of a map that came from Elixir (atom key) or from JSON (string key).
  """

  @doc """
  The value under `key`. Given an atom, the atom key wins when the map has it —
  even holding `nil` or `false` — and the string spelling is read otherwise.
  Anything that is not a map has no fields.
  """
  @spec get(term(), atom() | String.t()) :: term()
  def get(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  def get(map, key) when is_map(map) and is_binary(key), do: Map.get(map, key)
  def get(_map, _key), do: nil
end
