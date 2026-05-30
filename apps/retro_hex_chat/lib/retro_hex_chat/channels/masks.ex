defmodule RetroHexChat.Channels.Masks do
  @moduledoc """
  IRC-style nick mask matching used by channel bans and exceptions.
  """

  @spec matches_any?(Enumerable.t(), String.t() | nil) :: boolean()
  def matches_any?(masks, nickname) do
    Enum.any?(masks, &matches?(&1, nickname))
  end

  @spec matches?(String.t(), String.t() | nil) :: boolean()
  def matches?(_mask, nil), do: false

  def matches?(mask, nickname) do
    nick_pattern =
      mask
      |> to_string()
      |> String.split("!", parts: 2)
      |> List.first()

    nick_pattern != "" and wildcard_match?(nick_pattern, nickname)
  end

  defp wildcard_match?(pattern, value) do
    regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")
      |> String.replace("\\?", ".")

    Regex.match?(Regex.compile!("^#{regex}$", "i"), value)
  end
end
