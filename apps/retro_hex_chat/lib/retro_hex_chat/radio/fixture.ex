defmodule RetroHexChat.Radio.Fixture do
  @moduledoc """
  Hex Radio's catalog in the browser tests: a fixed list of stations in Radio
  Browser's shape, so a spec never depends on the internet or on which
  stations are on the air today.

  Their streams live on `radio.e2e.test`, a name that resolves nowhere: a spec
  answers them itself (Playwright's `page.route`), with or without the CORS
  header that decides whether the spectrum is real.
  """

  @behaviour RetroHexChat.Radio.Catalog

  @stations [
    {"e2e-pixel", "Pixel Wave FM", "chiptune,8-bit,video game music", "JP", "MP3", 128},
    {"e2e-neon", "Neon Highway", "synthwave,80s,retrowave", "US", "MP3", 192},
    {"e2e-modem", "Dial-Up Lounge", "lofi,chill,90s", "BR", "AAC", 96},
    {"e2e-bits", "Eight Bits Jazz", "jazz,smooth jazz", "FR", "OGG", 128},
    {"e2e-cart", "Cartridge Rock", "rock,classic rock,80s", "GB", "MP3", 160},
    {"e2e-star", "Starfield Ambient", "ambient,space", "DE", "OPUS", 64}
  ]

  @impl true
  def records(:top, limit), do: {:ok, Enum.take(all(), limit)}

  def records({:tag, tag}, limit),
    do: {:ok, all() |> Enum.filter(&(tag in String.split(&1["tags"], ","))) |> Enum.take(limit)}

  def records({:name, text}, limit) do
    text = String.downcase(text)

    {:ok,
     all()
     |> Enum.filter(&String.contains?(String.downcase(&1["name"]), text))
     |> Enum.take(limit)}
  end

  def records({:ids, ids}, _limit), do: {:ok, Enum.filter(all(), &(&1["stationuuid"] in ids))}

  @impl true
  def played(_id), do: :ok

  defp all do
    for {id, name, tags, country, codec, bitrate} <- @stations do
      %{
        "stationuuid" => id,
        "name" => name,
        "url_resolved" => "https://radio.e2e.test/#{id}.mp3",
        "homepage" => "https://radio.e2e.test/",
        "tags" => tags,
        "countrycode" => country,
        "codec" => codec,
        "bitrate" => bitrate,
        "hls" => 0,
        "lastcheckok" => 1,
        "ssl_error" => 0
      }
    end
  end
end
