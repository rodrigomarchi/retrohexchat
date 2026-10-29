defmodule RetroHexChat.Radio.RadioBrowserTest do
  @moduledoc """
  The questions Hex Radio asks Radio Browser, and what it does with the
  answers, against `Req.Test` — the shape of a real answer is in `@record`.
  """
  use ExUnit.Case, async: false

  alias RetroHexChat.Radio.RadioBrowser

  @moduletag :unit

  @record %{
    "stationuuid" => "32f62475-8900-4364-9fee-d1909f06ae2d",
    "name" => "Gamesboro Radio - Video Game Music 24/7",
    "url_resolved" => "https://radio.gamesboro.org/listen/gamesboro_radio/radio.mp3",
    "codec" => "MP3",
    "hls" => 0
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:retro_hex_chat, :radio_req_options, plug: {Req.Test, __MODULE__})
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :radio_req_options) end)
    :ok
  end

  test "asks for a genre's HTTPS stations that work, most played first" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/json/stations/search"
      params = URI.decode_query(conn.query_string)
      assert params["tag"] == "chiptune"
      assert params["tagExact"] == "true"
      assert params["is_https"] == "true"
      assert params["hidebroken"] == "true"
      assert params["order"] == "clickcount"
      assert params["limit"] == "100"
      assert ["RetroHexChat/" <> _] = Plug.Conn.get_req_header(conn, "user-agent")
      Req.Test.json(conn, [@record])
    end)

    assert {:ok, [@record]} = RadioBrowser.records({:tag, "chiptune"}, 100)
  end

  test "searches by name and reads favourites by id" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string)["name"] == "gamesboro"
      Req.Test.json(conn, [@record])
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/json/stations/byuuid"
      assert URI.decode_query(conn.query_string)["uuids"] == "a,b"
      Req.Test.json(conn, [])
    end)

    assert {:ok, [_]} = RadioBrowser.records({:name, "gamesboro"}, 100)
    assert {:ok, []} = RadioBrowser.records({:ids, ["a", "b"]}, 100)
  end

  test "an answer that is not a list of stations is an error" do
    Req.Test.expect(__MODULE__, &Plug.Conn.send_resp(&1, 503, "down"))
    assert {:error, {:status, 503}} = RadioBrowser.records(:top, 10)

    Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))
    assert {:error, {:transport, _}} = RadioBrowser.records(:top, 10)
  end
end
