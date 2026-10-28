defmodule RetroHexChat.Chat.Content.IrcArt do
  @moduledoc """
  A block of text art in mIRC colours: several lines sent as one message and
  shown as they were drawn, each character in its column.

  An IRC message is one line, and art pasted line by line arrives as a run of
  messages that every reader's flood protection takes for a flood. Here the
  whole picture is one message; its lines keep their breaks and render one
  under the other in a fixed-width block. The limit on format codes applies to
  each line, because a coloured row spends a code on nearly every character.
  """

  alias RetroHexChat.Chat.Formatter

  @type safe_html :: {:safe, String.t()}

  @max_lines 30
  @max_columns 100
  # Room for every cell of a full block to change both colours (`\x03NN,NN` and
  # its character, six characters a cell) with the line breaks.
  @max_length @max_lines * (@max_columns * 6 + 1)

  @doc "The most lines a block may have."
  @spec max_lines() :: pos_integer()
  def max_lines, do: @max_lines

  @doc "The most visible characters a line may have."
  @spec max_columns() :: pos_integer()
  def max_columns, do: @max_columns

  @doc "The longest a block may be, codes included."
  @spec max_length() :: pos_integer()
  def max_length, do: @max_length

  @spec render_html(String.t(), keyword()) :: safe_html()
  def render_html(content, opts) do
    rows =
      content
      |> lines()
      |> Enum.map_join("\n", fn line ->
        {:safe, html} = Formatter.to_safe_html(line, opts)
        IO.iodata_to_binary(html)
      end)

    {:safe, ~s(<pre class="irc-art">) <> rows <> "</pre>"}
  end

  @doc "The block's visible text, one line under the other."
  @spec plain_text(String.t()) :: String.t()
  def plain_text(content),
    do: content |> lines() |> Enum.map_join("\n", &Formatter.visible_text/1)

  @doc "The block's first line with something on it, for a one-line preview."
  @spec first_line(String.t()) :: String.t()
  def first_line(content) do
    content
    |> lines()
    |> Enum.map(&Formatter.visible_text/1)
    |> Enum.find("", &(String.trim(&1) != ""))
  end

  @spec extract_urls(String.t()) :: [String.t()]
  def extract_urls(_content), do: []

  @doc "Whether the block fits: at most `max_lines/0` lines of `max_columns/0` visible characters."
  @spec check_size(String.t()) :: :ok | {:error, :art_too_large}
  def check_size(content) do
    lines = lines(content)

    if length(lines) <= @max_lines and
         Enum.all?(lines, &(String.length(Formatter.visible_text(&1)) <= @max_columns)) do
      :ok
    else
      {:error, :art_too_large}
    end
  end

  # The lines as written, without the blank ones a paste leaves at the end.
  defp lines(content) do
    content
    |> String.split(~r/\r\n|\r|\n/)
    |> Enum.reverse()
    |> Enum.drop_while(&(String.trim(Formatter.visible_text(&1)) == ""))
    |> Enum.reverse()
  end
end
