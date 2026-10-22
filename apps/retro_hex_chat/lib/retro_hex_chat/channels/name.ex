defmodule RetroHexChat.Channels.Name do
  @moduledoc """
  What a channel name may be, and the one way a bare name becomes one.

  A name starts with `#`, has something after it, holds no whitespace and fits
  the columns that store it. `/join`, autojoin, auto-respond filters, share
  links and the reconnect snapshot all ask here, so a name one of them accepts
  is never refused by another.
  """

  @max_length 50

  @type problem :: :no_prefix | :empty | :too_long | :whitespace

  @doc "The longest name, in characters; the columns that store one are this wide."
  @spec max_length() :: pos_integer()
  def max_length, do: @max_length

  @doc "`:ok`, or what is wrong with `name`."
  @spec check(term()) :: :ok | {:error, problem()}
  def check("#" <> rest = name) do
    cond do
      rest == "" -> {:error, :empty}
      String.length(name) > @max_length -> {:error, :too_long}
      String.match?(name, ~r/\s/u) -> {:error, :whitespace}
      true -> :ok
    end
  end

  def check(_name), do: {:error, :no_prefix}

  @doc "Whether `name` is a channel name."
  @spec valid?(term()) :: boolean()
  def valid?(name), do: check(name) == :ok

  @doc """
  `name` with its `#`: a person typing a channel, or a URL that cannot carry
  the `#`, leaves it off.
  """
  @spec ensure_prefix(String.t()) :: String.t()
  def ensure_prefix("#" <> _rest = name), do: name
  def ensure_prefix(name) when is_binary(name), do: "#" <> name
end
