defmodule RetroHexChat.Chat.TimeFormatter do
  @moduledoc """
  Utility for formatting time durations and relative timestamps
  into human-friendly strings.
  """

  @spec format_duration(non_neg_integer()) :: String.t()
  def format_duration(0), do: "less than a minute"

  def format_duration(seconds) when is_integer(seconds) and seconds > 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    parts =
      []
      |> maybe_add(hours, "hour", "hours")
      |> maybe_add(minutes, "minute", "minutes")

    case parts do
      [] -> "less than a minute"
      _ -> Enum.join(parts, " ")
    end
  end

  @spec format_relative(DateTime.t()) :: String.t()
  def format_relative(%DateTime{} = timestamp) do
    seconds = DateTime.diff(DateTime.utc_now(), timestamp, :second)

    if seconds < 0 do
      "just now"
    else
      format_duration(seconds) <> " ago"
    end
  end

  @spec maybe_add([String.t()], non_neg_integer(), String.t(), String.t()) :: [String.t()]
  defp maybe_add(parts, 0, _singular, _plural), do: parts
  defp maybe_add(parts, 1, singular, _plural), do: parts ++ ["1 #{singular}"]
  defp maybe_add(parts, n, _singular, plural), do: parts ++ ["#{n} #{plural}"]
end
