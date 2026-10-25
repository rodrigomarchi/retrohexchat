defmodule RetroHexChatWeb.Params do
  @moduledoc """
  Reading a value an event or a channel message carried in.

  A `phx-value-*` arrives as a string, a hook's push as whatever JSON gave, a
  test as an integer: every handler that wants a number reads it here, the
  same way, and gets `default` for anything that is not one whole number.
  Yes/no values and map fields that may arrive under an atom or a string key
  are read here the same way.
  """

  @true_values [true, "true", "on", "1", 1]
  @false_values [false, "false", "off", "0", 0]

  @spec integer(term(), default) :: integer() | default when default: term()
  def integer(value, default \\ nil)
  def integer(value, _default) when is_integer(value), do: value

  def integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {integer, ""} -> integer
      _other -> default
    end
  end

  def integer(_value, default), do: default

  @doc ~s(A checkbox, toggle or flag that says yes: `true`, `"true"`, `"on"`, `"1"` or `1`.)
  @spec truthy?(term()) :: boolean()
  def truthy?(value), do: value in @true_values

  @doc "A yes/no value read both ways; anything that says neither gives `default`."
  @spec boolean(term(), default) :: boolean() | default when default: term()
  def boolean(value, _default) when value in @true_values, do: true
  def boolean(value, _default) when value in @false_values, do: false
  def boolean(_value, default), do: default

  @doc "A field of a map that came from Elixir (atom key) or from JSON (string key); see `RetroHexChat.MapKey.get/2`."
  @spec value(term(), atom() | String.t()) :: term()
  defdelegate value(map, key), to: RetroHexChat.MapKey, as: :get
end
