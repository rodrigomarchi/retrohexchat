defmodule RetroHexChat.Radio.StationTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Radio.Station

  @moduletag :unit

  @record %{
    "stationuuid" => "abc",
    "name" => "  Pixel Wave FM ",
    "url" => "http://old.example/stream",
    "url_resolved" => "https://radio.example/stream.mp3",
    "homepage" => "http://radio.example/",
    "tags" => "chiptune, 8-bit,,video game music,retro",
    "countrycode" => "JP",
    "codec" => "mp3",
    "bitrate" => 128,
    "hls" => 0,
    "lastcheckok" => 1,
    "ssl_error" => 0
  }

  test "reads what the list shows and the stream it plays" do
    assert {:ok, station} = Station.from_record(@record)
    assert station.id == "abc"
    assert station.name == "Pixel Wave FM"
    assert station.stream == "https://radio.example/stream.mp3"
    assert station.country == "JP"
    assert station.codec == "MP3"
    assert station.bitrate == 128
    assert station.tags == ["chiptune", "8-bit", "video game music"]
    # A homepage over plain HTTP is not linked from an HTTPS page.
    assert station.homepage == nil
  end

  test "skips what an HTTPS page cannot play" do
    for change <- [
          %{"url_resolved" => "http://radio.example/stream"},
          %{"hls" => 1},
          %{"ssl_error" => 1},
          %{"lastcheckok" => 0},
          %{"codec" => "WMA"},
          %{"name" => "   "}
        ] do
      assert Station.from_record(Map.merge(@record, change)) == :skip, inspect(change)
    end
  end

  test "a record without an id or a name is skipped" do
    assert Station.from_record(Map.delete(@record, "stationuuid")) == :skip
    assert Station.from_record(%{}) == :skip
  end
end
