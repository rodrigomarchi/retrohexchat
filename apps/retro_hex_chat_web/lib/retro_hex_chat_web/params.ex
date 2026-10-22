defmodule RetroHexChatWeb.Params do
  @moduledoc """
  Reading a value an event or a channel message carried in.

  A `phx-value-*` arrives as a string, a hook's push as whatever JSON gave, a
  test as an integer: every handler that wants a number reads it here, the
  same way, and gets `default` for anything that is not one whole number.
  """

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
end
