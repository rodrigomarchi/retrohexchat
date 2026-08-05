defmodule RetroHexChatWeb.Components.UI.Format do
  @moduledoc """
  Turning measured figures into the strings a reader can take in at a glance.

  A monitor is mostly large integers, and a large integer rendered raw is
  unreadable: `118681036` says nothing that `113.2 MB` does not say better. The
  conversions live here rather than in each panel so that a byte count means
  the same thing on every screen that shows one.

  Precision is deliberately low. These are diagnostic readings watched over
  time, and a figure that redraws every few seconds with six significant digits
  reads as noise — the eye tracks the magnitude, not the last digit.
  """

  @kilobyte 1024
  @megabyte 1024 * @kilobyte
  @gigabyte 1024 * @megabyte

  @second 1000
  @minute 60 * @second
  @hour 60 * @minute
  @day 24 * @hour

  @doc """
  A byte count at the largest unit that keeps it under four digits.

  Bytes themselves are never fractional; anything larger carries one decimal,
  which is the resolution at which a change is meaningful.
  """
  @spec bytes(term()) :: String.t()
  def bytes(value) when is_integer(value) and value >= @gigabyte do
    "#{round_to(value / @gigabyte)} GB"
  end

  def bytes(value) when is_integer(value) and value >= @megabyte do
    "#{round_to(value / @megabyte)} MB"
  end

  def bytes(value) when is_integer(value) and value >= @kilobyte do
    "#{round_to(value / @kilobyte)} KB"
  end

  def bytes(value) when is_integer(value), do: "#{value} B"
  def bytes(_value), do: "—"

  @doc """
  An integer with thin spaces between thousands.

  A space rather than a comma or a period, because the same screen is read in
  locales that disagree about which of those two means "decimal".
  """
  @spec number(term()) :: String.t()
  def number(value) when is_integer(value) and value < 0, do: "-" <> number(-value)

  def number(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(" ")
    |> String.reverse()
  end

  def number(value) when is_float(value), do: value |> round() |> number()
  def number(_value), do: "—"

  @doc """
  A duration as its two largest units.

  Uptime is read as "how long has this been up", and `9m` or `3d 4h` answers
  that; seconds beyond the first minute are never the question.
  """
  @spec duration_ms(term()) :: String.t()
  def duration_ms(value) when is_integer(value) and value >= @day do
    "#{div(value, @day)}d #{rem(div(value, @hour), 24)}h"
  end

  def duration_ms(value) when is_integer(value) and value >= @hour do
    "#{div(value, @hour)}h #{rem(div(value, @minute), 60)}m"
  end

  def duration_ms(value) when is_integer(value) and value >= @minute do
    "#{div(value, @minute)}m #{rem(div(value, @second), 60)}s"
  end

  def duration_ms(value) when is_integer(value) and value >= @second do
    "#{div(value, @second)}s"
  end

  def duration_ms(value) when is_integer(value) and value >= 0, do: "#{value}ms"
  def duration_ms(_value), do: "—"

  @doc "A percentage at one decimal."
  @spec percent(term()) :: String.t()
  def percent(value) when is_float(value), do: "#{Float.round(value, 1)}%"
  def percent(value) when is_integer(value), do: "#{value}%"
  def percent(_value), do: "—"

  @doc """
  Formats a table cell according to the format its column declares.

  The column knows what its figures mean; the cell is just an integer. Routing
  through here is what keeps a byte count from rendering as a bare number
  because one panel forgot to convert it.
  """
  @spec cell(term(), atom()) :: String.t()
  def cell(nil, _format), do: ""
  def cell(true, _format), do: "✓"
  def cell(false, _format), do: "—"
  def cell(value, :bytes), do: bytes(value)
  def cell(value, :number), do: number(value)
  def cell(value, :duration_ms), do: duration_ms(value)
  def cell(value, :percent), do: percent(value)
  def cell(%DateTime{} = value, _format), do: DateTime.to_string(value)
  def cell(value, _format) when is_binary(value), do: value
  def cell(value, _format), do: to_string(value)

  # 113.2 rather than 113.24999999999999, and 113 rather than 113.0 — a
  # trailing zero after the point is a digit that carries no information.
  defp round_to(value) do
    rounded = Float.round(value, 1)

    if rounded == Float.round(rounded, 0) do
      trunc(rounded)
    else
      rounded
    end
  end
end
