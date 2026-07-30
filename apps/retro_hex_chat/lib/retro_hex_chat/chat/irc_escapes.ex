defmodule RetroHexChat.Chat.IrcEscapes do
  @moduledoc """
  Decodes readable escape sequences into mIRC formatting control codes.

  This is intentionally opt-in for configured automation text. Normal chat input
  already uses literal mIRC control bytes from the composer toolbar; scripts and
  admin console snippets need something reviewable in plain text.
  """

  @bold <<0x02>>
  @colour <<0x03>>
  @reset <<0x0F>>
  @reverse <<0x16>>
  @italic <<0x1D>>
  @strikethrough <<0x1E>>
  @underline <<0x1F>>

  @known_hex %{
    "02" => @bold,
    "03" => @colour,
    "0f" => @reset,
    "0F" => @reset,
    "16" => @reverse,
    "1d" => @italic,
    "1D" => @italic,
    "1e" => @strikethrough,
    "1E" => @strikethrough,
    "1f" => @underline,
    "1F" => @underline
  }

  @doc """
  Converts visible escapes to control bytes.

  Supported escapes:

    * `\\c04` or `\\c04,01` - foreground or foreground/background colour.
    * `\\b`, `\\i`, `\\u`, `\\s`, `\\v`, `\\o` - bold, italic, underline,
      strikethrough, reverse, reset.
    * `\\x02`, `\\x03`, `\\x0F`, `\\x16`, `\\x1D`, `\\x1E`, `\\x1F`.
    * `\\\\` - a literal backslash.
  """
  @spec decode(String.t()) :: String.t()
  def decode(text) when is_binary(text) do
    text
    |> do_decode([])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp do_decode(<<>>, acc), do: acc
  defp do_decode(<<"\\\\", rest::binary>>, acc), do: do_decode(rest, ["\\" | acc])
  defp do_decode(<<"\\b", rest::binary>>, acc), do: do_decode(rest, [@bold | acc])
  defp do_decode(<<"\\i", rest::binary>>, acc), do: do_decode(rest, [@italic | acc])
  defp do_decode(<<"\\u", rest::binary>>, acc), do: do_decode(rest, [@underline | acc])
  defp do_decode(<<"\\s", rest::binary>>, acc), do: do_decode(rest, [@strikethrough | acc])
  defp do_decode(<<"\\v", rest::binary>>, acc), do: do_decode(rest, [@reverse | acc])
  defp do_decode(<<"\\o", rest::binary>>, acc), do: do_decode(rest, [@reset | acc])

  defp do_decode(<<"\\x", h1, h2, rest::binary>>, acc) do
    hex = <<h1, h2>>

    case Map.fetch(@known_hex, hex) do
      {:ok, control} -> do_decode(rest, [control | acc])
      :error -> do_decode(rest, [hex, "\\x" | acc])
    end
  end

  defp do_decode(<<"\\c", rest::binary>>, acc) do
    case parse_colour(rest) do
      {:ok, args, remaining} -> do_decode(remaining, [args, @colour | acc])
      :error -> do_decode(rest, ["\\c" | acc])
    end
  end

  defp do_decode(<<char::utf8, rest::binary>>, acc) do
    do_decode(rest, [<<char::utf8>> | acc])
  end

  defp parse_colour(rest) do
    with {:ok, fg, remaining} <- read_colour_number(rest) do
      parse_background(fg, remaining)
    end
  end

  defp parse_background(fg, <<",", rest::binary>>) do
    case read_colour_number(rest) do
      {:ok, bg, remaining} -> {:ok, fg <> "," <> bg, remaining}
      :error -> {:ok, fg, <<",", rest::binary>>}
    end
  end

  defp parse_background(fg, remaining), do: {:ok, fg, remaining}

  defp read_colour_number(<<d1, d2, rest::binary>>)
       when d1 in ?0..?9 and d2 in ?0..?9 do
    two_digit = (d1 - ?0) * 10 + (d2 - ?0)

    if two_digit <= 15 do
      {:ok, pad_colour(two_digit), rest}
    else
      {:ok, pad_colour(d1 - ?0), <<d2, rest::binary>>}
    end
  end

  defp read_colour_number(<<d1, rest::binary>>) when d1 in ?0..?9 do
    {:ok, pad_colour(d1 - ?0), rest}
  end

  defp read_colour_number(_rest), do: :error

  defp pad_colour(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")
end
