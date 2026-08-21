defmodule RetroHexChat.Scraper.VixImageThumbnailer do
  @moduledoc """
  Builds scraper thumbnails with libvips through Vix.
  """

  @behaviour RetroHexChat.Scraper.ImageThumbnailer

  alias RetroHexChat.Scraper.ImageThumbnailer
  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation

  @default_width 640
  @default_height 360
  @jpeg_quality 82

  @impl true
  @spec thumbnail(binary(), keyword()) :: {:ok, ImageThumbnailer.thumbnail()} | {:error, term()}
  def thumbnail(body, opts \\ []) when is_binary(body) do
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)

    with {:ok, thumb} <-
           Operation.thumbnail_buffer(body, width,
             height: height,
             crop: :VIPS_INTERESTING_ATTENTION,
             size: :VIPS_SIZE_DOWN
           ),
         {:ok, flattened} <- flatten_alpha(thumb),
         {:ok, encoded} <-
           VipsImage.write_to_buffer(flattened, ".jpg", Q: @jpeg_quality, strip: true) do
      {:ok,
       %{
         body: encoded,
         content_type: "image/jpeg",
         extension: "jpg",
         width: VipsImage.width(flattened),
         height: VipsImage.height(flattened),
         byte_size: byte_size(encoded)
       }}
    else
      {:error, reason} -> {:error, {:image_processing_failed, reason}}
    end
  rescue
    exception -> {:error, {:image_processing_failed, Exception.message(exception)}}
  end

  @spec flatten_alpha(VipsImage.t()) :: {:ok, VipsImage.t()} | {:error, term()}
  defp flatten_alpha(image) do
    if VipsImage.has_alpha?(image) do
      Operation.flatten(image, background: [255.0, 255.0, 255.0])
    else
      {:ok, image}
    end
  end
end
