defmodule RetroHexChat.Commands.Handler.Args do
  @moduledoc """
  Reading the words a "/" command was typed with.

  A nickname copied from the nicklist arrives with its `@`, an option is a
  flag followed by its value, an id is a positive whole number: the same
  readings for every handler, so `/admin user @alice` and `/admin log @alice`
  understand the same nickname.
  """

  @doc "A nickname as typed, without the `@` an operator's name is shown with."
  @spec nickname(String.t()) :: String.t()
  def nickname("@" <> nick), do: nick
  def nickname(nick), do: nick

  @doc "The word after `flag` among `args` (`--reason spam` gives `\"spam\"`), or `nil`."
  @spec option([String.t()], String.t()) :: String.t() | nil
  def option(args, flag) do
    case Enum.find_index(args, &(&1 == flag)) do
      nil -> nil
      index -> Enum.at(args, index + 1)
    end
  end

  @doc "A positive whole number written as `raw`, or `{:error, error}`."
  @spec positive_id(term(), error) :: {:ok, pos_integer()} | {:error, error} when error: term()
  def positive_id(raw, error) when is_binary(raw) do
    case Integer.parse(String.trim(raw)) do
      {id, ""} when id > 0 -> {:ok, id}
      _other -> {:error, error}
    end
  end

  def positive_id(_raw, error), do: {:error, error}
end
