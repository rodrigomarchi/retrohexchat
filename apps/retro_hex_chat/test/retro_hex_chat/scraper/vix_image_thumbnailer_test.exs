defmodule RetroHexChat.Scraper.VixImageThumbnailerTest do
  @moduledoc """
  The real libvips encode: the format and frame every stored thumbnail ends up in.
  """

  use ExUnit.Case, async: true

  alias RetroHexChat.Scraper.VixImageThumbnailer
  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation

  @moduletag :unit

  test "encodes a landscape photo as WebP cropped to 480x270" do
    {:ok, thumbnail} = VixImageThumbnailer.thumbnail(png(1200, 800))

    assert thumbnail.content_type == "image/webp"
    assert thumbnail.extension == "webp"
    assert {thumbnail.width, thumbnail.height} == {480, 270}
    assert thumbnail.byte_size == byte_size(thumbnail.body)
    assert <<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>> = thumbnail.body
  end

  test "never enlarges an image smaller than the frame" do
    {:ok, thumbnail} = VixImageThumbnailer.thumbnail(png(200, 100))

    assert thumbnail.width <= 200
    assert thumbnail.height <= 100
  end

  test "flattens transparency onto white, since WebP output carries no alpha here" do
    # `xyz` yields two bands; joining two of them gives the four a PNG reads as RGBA.
    {:ok, two_bands} = Operation.xyz(640, 360)
    {:ok, two_bands} = Operation.cast(two_bands, :VIPS_FORMAT_UCHAR)
    {:ok, rgba} = Operation.bandjoin([two_bands, two_bands])
    {:ok, body} = VipsImage.write_to_buffer(rgba, ".png")
    {:ok, source} = VipsImage.new_from_buffer(body)
    assert VipsImage.has_alpha?(source)

    {:ok, thumbnail} = VixImageThumbnailer.thumbnail(body)
    {:ok, decoded} = VipsImage.new_from_buffer(thumbnail.body)

    refute VipsImage.has_alpha?(decoded)
  end

  test "reports undecodable bytes as a processing failure" do
    assert {:error, {:image_processing_failed, _reason}} =
             VixImageThumbnailer.thumbnail("not an image")
  end

  defp png(width, height) do
    {:ok, image} = Operation.xyz(width, height)
    {:ok, image} = Operation.cast(image, :VIPS_FORMAT_UCHAR)
    {:ok, body} = VipsImage.write_to_buffer(image, ".png")
    body
  end
end
