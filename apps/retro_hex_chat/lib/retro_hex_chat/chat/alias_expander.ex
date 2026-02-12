defmodule RetroHexChat.Chat.AliasExpander do
  @moduledoc """
  Pure variable expansion engine shared by aliases, custom menus,
  auto-respond rules, and timers.

  Supported variables:
    - $1 through $9: positional arguments
    - $nick: the user's own nickname
    - $chan: the current channel name (empty string if nil)
    - $$: literal dollar sign
  """

  @chaining_pattern ~r/[|;\r\n]|&&/

  @spec expand(String.t(), [String.t()], %{nick: String.t(), chan: String.t() | nil}) ::
          String.t()
  def expand(template, args, context) do
    template
    |> replace_escaped_dollars()
    |> replace_positional_args(args)
    |> replace_context_vars(context)
    |> restore_escaped_dollars()
  end

  @spec validate_expansion(String.t()) :: :ok | {:error, String.t()}
  def validate_expansion(expansion) do
    if contains_chaining?(expansion) do
      {:error, "Expansion must not contain command chaining characters (|, &&, ;, or newlines)"}
    else
      :ok
    end
  end

  @spec contains_chaining?(String.t()) :: boolean()
  def contains_chaining?(text) do
    Regex.match?(@chaining_pattern, text)
  end

  # -- Private helpers --

  @placeholder "\x00DOLLAR\x00"

  defp replace_escaped_dollars(text) do
    String.replace(text, "$$", @placeholder)
  end

  defp restore_escaped_dollars(text) do
    String.replace(text, @placeholder, "$")
  end

  defp replace_positional_args(text, args) do
    Enum.reduce(1..9, text, fn i, acc ->
      value = Enum.at(args, i - 1, "")
      String.replace(acc, "$#{i}", value)
    end)
  end

  defp replace_context_vars(text, %{nick: nick, chan: chan}) do
    text
    |> String.replace("$nick", nick)
    |> String.replace("$chan", chan || "")
  end
end
