defmodule RetroHexChatWeb.Timezone do
  @moduledoc """
  Timezone helpers for converting UTC DateTimes to the user's local timezone.
  Web layer only — domain modules remain timezone-agnostic.
  """

  @doc """
  Shifts a UTC DateTime to the given IANA timezone.
  Returns the original DateTime unchanged if the timezone is invalid or "Etc/UTC".
  """
  @spec shift(DateTime.t(), String.t()) :: DateTime.t()
  def shift(%DateTime{} = dt, "Etc/UTC"), do: dt

  def shift(%DateTime{} = dt, timezone) when is_binary(timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> shifted
      {:error, _} -> dt
    end
  end

  def shift(dt, _timezone), do: dt

  @doc """
  Validates a timezone string. Returns the timezone if valid, "Etc/UTC" otherwise.
  """
  @spec validate(String.t() | nil) :: String.t()
  def validate(nil), do: "Etc/UTC"

  def validate(timezone) when is_binary(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(), timezone) do
      {:ok, _} -> timezone
      {:error, _} -> "Etc/UTC"
    end
  end

  def validate(_), do: "Etc/UTC"

  @doc """
  Formats a timezone's UTC offset as a human-readable string like "UTC-3" or "UTC+5:30".
  """
  @spec format_utc_offset(String.t()) :: String.t()
  def format_utc_offset("Etc/UTC"), do: "UTC"

  def format_utc_offset(timezone) when is_binary(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(), timezone) do
      {:ok, dt} -> format_offset(dt.utc_offset + dt.std_offset)
      {:error, _} -> "UTC"
    end
  end

  def format_utc_offset(_), do: "UTC"

  @spec format_offset(integer()) :: String.t()
  defp format_offset(0), do: "UTC"

  defp format_offset(total_seconds) do
    sign = if total_seconds >= 0, do: "+", else: "-"
    abs_seconds = abs(total_seconds)
    hours = div(abs_seconds, 3600)
    minutes = div(rem(abs_seconds, 3600), 60)

    if minutes == 0 do
      "UTC#{sign}#{hours}"
    else
      "UTC#{sign}#{hours}:#{String.pad_leading(Integer.to_string(minutes), 2, "0")}"
    end
  end
end
