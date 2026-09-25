defmodule RetroHexChat.Chat.TimeFormatter do
  @moduledoc """
  Utility for formatting time durations and relative timestamps
  into human-friendly strings.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @seconds_per_day 86_400

  @spec format_duration(non_neg_integer()) :: String.t()
  def format_duration(0), do: dgettext("chat", "less than a minute")

  def format_duration(seconds) when is_integer(seconds) and seconds > 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    parts =
      []
      |> maybe_add(hours, &hours/1)
      |> maybe_add(minutes, &minutes/1)

    case parts do
      [] -> dgettext("chat", "less than a minute")
      _ -> Enum.join(parts, " ")
    end
  end

  @doc """
  A number of days, spelled the way the reader's language spells it.

  Every screen that quotes an expiry window reads it from here instead of
  writing the sentence itself. The window is configuration, so the number is
  not known when the sentence is written, and a sentence per screen would be a
  plural rule per screen in fourteen languages — the same rule, restated seven
  times, wrong in six of them by the second edit.
  """
  @spec days(pos_integer()) :: String.t()
  def days(count) when is_integer(count) and count > 0 do
    dngettext("chat", "%{count} day", "%{count} days", count)
  end

  @doc """
  How long ago `timestamp` was, in the reader's language.

  Anything a day old or older counts in days. `format_duration/1` stops at
  hours because the timer dialog asks it for a countdown, where "72 hours" is
  the answer somebody set; as an age it is a number nobody says out loud, and a
  channel last used three days ago read exactly that.
  """
  @spec format_relative(DateTime.t()) :: String.t()
  def format_relative(%DateTime{} = timestamp) do
    seconds = DateTime.diff(DateTime.utc_now(), timestamp, :second)

    cond do
      seconds < 0 -> dgettext("chat", "just now")
      seconds >= @seconds_per_day -> ago(days(div(seconds, @seconds_per_day)))
      true -> ago(format_duration(seconds))
    end
  end

  @doc """
  How far off a future instant is, in words: "in 2 hours".

  The mirror of `format_relative/1`, and separate from it because the two are
  different sentences rather than the same one with a sign. Something that has
  already started says so instead of counting backwards — a countdown that goes
  negative is how a reminder comes to say "in -5 minutes".
  """
  @spec format_until(DateTime.t()) :: String.t()
  def format_until(%DateTime{} = timestamp) do
    seconds = DateTime.diff(timestamp, DateTime.utc_now(), :second)

    cond do
      seconds <= 0 -> dgettext("chat", "now")
      seconds >= @seconds_per_day -> ahead(days(div(seconds, @seconds_per_day)))
      true -> ahead(format_duration(seconds))
    end
  end

  defp ago(span), do: dgettext("chat", "%{span} ago", span: span)
  defp ahead(span), do: dgettext("chat", "in %{span}", span: span)

  @spec hours(pos_integer()) :: String.t()
  defp hours(count), do: dngettext("chat", "%{count} hour", "%{count} hours", count)

  @spec minutes(pos_integer()) :: String.t()
  defp minutes(count), do: dngettext("chat", "%{count} minute", "%{count} minutes", count)

  # The unit words used to be interpolated as English literals, so every
  # duration read half-translated in thirteen languages.
  @spec maybe_add([String.t()], non_neg_integer(), (pos_integer() -> String.t())) :: [String.t()]
  defp maybe_add(parts, 0, _spell), do: parts
  defp maybe_add(parts, n, spell), do: parts ++ [spell.(n)]
end
