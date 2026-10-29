defmodule RetroHexChat.Radio.Station do
  @moduledoc """
  A radio station Hex Radio can play: what the list shows of it and the
  address its stream is read from.

  Built from a Radio Browser record by `from_record/1`, which also decides
  whether the station is playable here at all: the page is served over HTTPS,
  so a stream that is not is blocked by the browser, and a playlist format
  (HLS) needs a player of its own.
  """

  @enforce_keys [:id, :name, :stream]
  defstruct [:id, :name, :stream, :homepage, :country, :codec, :bitrate, tags: []]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          stream: String.t(),
          homepage: String.t() | nil,
          country: String.t() | nil,
          codec: String.t() | nil,
          bitrate: non_neg_integer() | nil,
          tags: [String.t()]
        }

  # What an `<audio>` element plays in every browser the chat supports.
  @codecs ~w(MP3 AAC AAC+ OGG OPUS)
  @max_tags 3
  @max_name 80

  @doc """
  The station a Radio Browser record describes, or `:skip` when it cannot be
  played in the page: not HTTPS, a broken certificate, HLS, a codec the
  browser lacks, or a last check that failed.
  """
  @spec from_record(map()) :: {:ok, t()} | :skip
  def from_record(%{"stationuuid" => id, "name" => name} = record)
      when is_binary(id) and is_binary(name) do
    stream = record["url_resolved"] || record["url"]

    if playable?(record, stream) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name |> String.trim() |> String.slice(0, @max_name),
         stream: stream,
         homepage: https_or_nil(record["homepage"]),
         country: blank_to_nil(record["countrycode"]),
         codec: record["codec"] |> to_string() |> String.upcase() |> blank_to_nil(),
         bitrate: positive_or_nil(record["bitrate"]),
         tags: tags(record["tags"])
       }}
    else
      :skip
    end
  end

  def from_record(_record), do: :skip

  defp playable?(record, stream) do
    https?(stream) and String.trim(record["name"]) != "" and record["hls"] != 1 and
      record["ssl_error"] != 1 and record["lastcheckok"] != 0 and
      String.upcase(to_string(record["codec"])) in @codecs
  end

  defp https?("https://" <> rest), do: rest != ""
  defp https?(_url), do: false

  defp https_or_nil(url), do: if(https?(url), do: url)

  defp tags(tags) when is_binary(tags) do
    tags
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(@max_tags)
  end

  defp tags(_tags), do: []

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp positive_or_nil(value) when is_integer(value) and value > 0, do: value
  defp positive_or_nil(_value), do: nil
end
