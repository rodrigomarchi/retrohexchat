defmodule RetroHexChat.Scraper.Markup do
  @moduledoc """
  What the page scraper and the feed reader both read out of publishers'
  markup: HTML entities left in titles and summaries, `srcset` candidates and
  publication dates.
  """

  @entity_map %{
    "amp" => "&",
    "apos" => "'",
    "copy" => "©",
    "gt" => ">",
    "hellip" => "…",
    "laquo" => "«",
    "ldquo" => "“",
    "lsquo" => "‘",
    "lt" => "<",
    "mdash" => "—",
    "nbsp" => " ",
    "ndash" => "–",
    "quot" => "\"",
    "raquo" => "»",
    "rdquo" => "”",
    "reg" => "®",
    "rsquo" => "’",
    "trade" => "™"
  }

  @doc """
  Decodes numeric (`&#8217;`, `&#x2019;`) and common named entities. An
  unknown name is left as written rather than dropped.
  """
  @spec decode_entities(String.t()) :: String.t()
  def decode_entities(text) do
    text = Regex.replace(~r/&#x([0-9a-fA-F]+);/, text, fn _match, hex -> codepoint(hex, 16) end)
    text = Regex.replace(~r/&#([0-9]+);/, text, fn _match, int -> codepoint(int, 10) end)

    Regex.replace(~r/&([a-zA-Z][a-zA-Z0-9]+);/, text, fn match, name ->
      Map.get(@entity_map, String.downcase(name), match)
    end)
  end

  @spec codepoint(String.t(), 10 | 16) :: String.t()
  defp codepoint(value, base) do
    value
    |> String.to_integer(base)
    |> List.wrap()
    |> List.to_string()
  rescue
    _ -> ""
  end

  @doc "The widest candidate of a `srcset` attribute; `nil` when there is none."
  @spec srcset_url(String.t() | nil) :: String.t() | nil
  def srcset_url(nil), do: nil

  def srcset_url(srcset) do
    srcset
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn entry ->
      case String.split(entry) do
        [url, width | _] -> {url, srcset_width(width)}
        [url] -> {url, 0}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.max_by(&elem(&1, 1), fn -> nil end)
    |> case do
      {url, _width} -> url
      nil -> nil
    end
  end

  @spec srcset_width(String.t()) :: non_neg_integer()
  defp srcset_width(width) do
    width
    |> String.trim_trailing("w")
    |> String.to_integer()
  rescue
    _ -> 0
  end

  @doc """
  A publication date as publishers write it: ISO 8601, a bare date (midnight
  UTC) or the RFC 822 form feeds use (`Tue, 21 Oct 2026 10:00:00 GMT`).
  Anything else is `nil` rather than guessed at.
  """
  @spec parse_datetime(String.t() | nil) :: DateTime.t() | nil
  def parse_datetime(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> iso8601_datetime(trimmed) || rfc_datetime(trimmed)
    end
  end

  def parse_datetime(_value), do: nil

  @spec iso8601_datetime(String.t()) :: DateTime.t() | nil
  defp iso8601_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _reason} ->
        case Date.from_iso8601(value) do
          {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          {:error, _reason} -> nil
        end
    end
  rescue
    _ -> nil
  end

  @spec rfc_datetime(String.t()) :: DateTime.t() | nil
  defp rfc_datetime(value) do
    case :httpd_util.convert_request_date(String.to_charlist(value)) do
      {{year, month, day}, {hour, minute, second}} ->
        DateTime.new!(Date.new!(year, month, day), Time.new!(hour, minute, second), "Etc/UTC")

      _other ->
        nil
    end
  rescue
    _ -> nil
  end
end
