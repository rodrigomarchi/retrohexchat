defmodule RetroHexChat.Commands.Parser do
  @moduledoc """
  Parses raw input into commands or plain messages.
  """

  @spec parse(String.t()) :: {:command, String.t(), [String.t()]} | {:message, String.t()}
  def parse("/" <> rest) when byte_size(rest) > 0 do
    # Double slash is a regular message
    case rest do
      "/" <> _ ->
        {:message, "/" <> rest}

      _ ->
        [cmd | args] = String.split(rest, ~r/\s+/, trim: true)
        {:command, String.downcase(cmd), args}
    end
  end

  def parse(text), do: {:message, text}
end
