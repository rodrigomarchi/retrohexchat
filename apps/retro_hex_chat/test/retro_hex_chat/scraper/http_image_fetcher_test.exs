defmodule RetroHexChat.Scraper.HTTPImageFetcherTest do
  @moduledoc """
  Image download guardrails for scraper thumbnails.
  """

  use ExUnit.Case, async: false

  alias RetroHexChat.Scraper.HTTPImageFetcher

  @moduletag :unit

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:retro_hex_chat, :scraper_image_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn -> Application.delete_env(:retro_hex_chat, :scraper_image_req_options) end)
    :ok
  end

  test "accepts raster image bytes" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/png")
      |> Plug.Conn.resp(200, <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "rest">>)
    end)

    assert {:ok, image} = HTTPImageFetcher.fetch("https://93.184.216.34/story.png")

    assert image.content_type == "image/png"
    assert image.final_url == "https://93.184.216.34/story.png"
    assert image.byte_size > 0
  end

  test "rejects non-raster image bodies" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/svg+xml")
      |> Plug.Conn.resp(200, "<svg></svg>")
    end)

    assert {:error, :unsupported_image_type} =
             HTTPImageFetcher.fetch("https://93.184.216.34/story.svg")
  end
end
