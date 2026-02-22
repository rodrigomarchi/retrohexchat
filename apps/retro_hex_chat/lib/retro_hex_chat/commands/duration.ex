defmodule RetroHexChat.Commands.Duration do
  @moduledoc """
  Shared duration parsing and formatting for commands that accept
  time durations (e.g., /mute, /admin user ban, /ignore).

  Supports: `30s`, `5m`, `1h`, `1d`, or bare integers (seconds).
  """

  @spec parse(String.t() | nil) :: non_neg_integer() | :permanent
  def parse(nil), do: :permanent
  def parse(""), do: :permanent

  def parse(str) do
    case Integer.parse(str) do
      {n, "d"} -> n * 86_400
      {n, "h"} -> n * 3600
      {n, "m"} -> n * 60
      {n, "s"} -> n
      {n, ""} -> n
      _ -> :permanent
    end
  end

  @spec format(non_neg_integer() | :permanent) :: String.t()
  def format(:permanent), do: "permanently"

  def format(seconds) when is_integer(seconds) do
    cond do
      seconds >= 86_400 -> "#{div(seconds, 86_400)}d"
      seconds >= 3600 -> "#{div(seconds, 3600)}h"
      seconds >= 60 -> "#{div(seconds, 60)}m"
      true -> "#{seconds}s"
    end
  end

  def format(_), do: "unknown"
end
