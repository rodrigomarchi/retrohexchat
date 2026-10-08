defmodule RetroHexChat.Scraper.ImageCacheReencodeTest do
  @moduledoc """
  Shrinking thumbnails already in storage: real libvips, an in-memory bucket.
  """

  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Jobs.ScrapedThumbnailReencodeWorker
  alias RetroHexChat.Scraper.{ImageCache, ScrapedPage, Store}
  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation

  @moduletag :integration

  @bucket "retrohexchat-uploads"

  defmodule MemoryStorage do
    @moduledoc false
    @behaviour RetroHexChat.Chat.Attachments.Storage

    def start, do: Agent.start_link(fn -> %{} end, name: __MODULE__)
    def put(key, body), do: Agent.update(__MODULE__, &Map.put(&1, key, body))
    def keys, do: Agent.get(__MODULE__, &Map.keys/1)
    def fetch(key), do: Agent.get(__MODULE__, &Map.fetch(&1, key))

    @impl true
    def put_file(path, key, opts) do
      put(key, File.read!(path))
      {:ok, %{bucket: Keyword.fetch!(opts, :bucket), key: key}}
    end

    @impl true
    def get_file(_bucket, key, _opts) do
      case fetch(key) do
        {:ok, body} -> {:ok, body}
        :error -> {:error, :not_found}
      end
    end

    @impl true
    def delete_file(_bucket, key, _opts), do: Agent.update(__MODULE__, &Map.delete(&1, key))

    @impl true
    def presigned_put_url(_bucket, _key, _opts), do: {:error, :unsupported}

    @impl true
    def presigned_get_url(_bucket, _key, _opts), do: {:error, :unsupported}
  end

  setup do
    {:ok, _pid} = MemoryStorage.start()
    previous = Application.get_env(:retro_hex_chat, :scraped_image_cache)

    Application.put_env(:retro_hex_chat, :scraped_image_cache,
      storage: MemoryStorage,
      bucket: @bucket
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:retro_hex_chat, :scraped_image_cache, previous),
        else: Application.delete_env(:retro_hex_chat, :scraped_image_cache)
    end)

    :ok
  end

  describe "reencode_oversized/1" do
    test "replaces a 640x360 JPEG with a smaller WebP and deletes the old object" do
      page = page_with_thumbnail("https://example.com/big", 640, 360)
      old_key = page.image_thumbnail_storage_key

      summary = ImageCache.reencode_oversized()

      assert %{candidates: 1, reencoded: 1, skipped: 0} = summary
      assert summary.last_id == page.id
      assert summary.bytes_deleted > 0

      updated = Repo.get!(ScrapedPage, page.id)
      assert updated.image_thumbnail_content_type == "image/webp"
      assert {updated.image_thumbnail_width, updated.image_thumbnail_height} == {480, 270}
      assert updated.image_thumbnail_byte_size < page.image_thumbnail_byte_size
      assert updated.image_thumbnail_storage_key =~ ~r/480x270\.webp$/
      assert updated.image_thumbnail_status == "ready"
      assert updated.image_thumbnail_source_url == page.image_thumbnail_source_url

      assert MemoryStorage.keys() == [updated.image_thumbnail_storage_key]
      refute old_key in MemoryStorage.keys()
    end

    test "leaves thumbnails already within the frame alone" do
      page_with_thumbnail("https://example.com/small", 480, 270)

      assert %{candidates: 0, reencoded: 0, last_id: nil} = ImageCache.reencode_oversized()
    end

    test "skips a page whose object is gone and moves the cursor past it" do
      page = page_with_thumbnail("https://example.com/gone", 640, 360)
      MemoryStorage.delete_file(@bucket, page.image_thumbnail_storage_key, [])

      assert %{candidates: 1, reencoded: 0, skipped: 1, last_id: last_id} =
               ImageCache.reencode_oversized()

      assert last_id == page.id

      assert Repo.get!(ScrapedPage, page.id).image_thumbnail_storage_key ==
               page.image_thumbnail_storage_key

      assert %{candidates: 0} = ImageCache.reencode_oversized(after_id: last_id)
    end
  end

  describe "Store.replace_image_thumbnail/3" do
    test "refuses when the page no longer names the object it was read with" do
      page = page_with_thumbnail("https://example.com/moved", 640, 360)

      stored = %{
        storage_bucket: @bucket,
        storage_key: "scraper/images/new.webp",
        content_type: "image/webp",
        byte_size: 10,
        width: 480,
        height: 270
      }

      assert {:error, :stale} = Store.replace_image_thumbnail(page, "some/other/key.jpg", stored)

      assert {:ok, updated} =
               Store.replace_image_thumbnail(page, page.image_thumbnail_storage_key, stored)

      assert updated.image_thumbnail_storage_key == "scraper/images/new.webp"
    end
  end

  describe "ScrapedThumbnailReencodeWorker" do
    test "converts a batch and enqueues the next one from its last id" do
      page = page_with_thumbnail("https://example.com/walk", 640, 360)

      assert {:ok, %{reencoded: 1}} = perform_job(ScrapedThumbnailReencodeWorker, %{})

      assert_enqueued(
        worker: ScrapedThumbnailReencodeWorker,
        args: %{"after_id" => page.id, "limit" => 200}
      )
    end

    test "stops when nothing is left to convert" do
      assert {:ok, %{candidates: 0}} = perform_job(ScrapedThumbnailReencodeWorker, %{})

      refute_enqueued(worker: ScrapedThumbnailReencodeWorker)
    end
  end

  defp page_with_thumbnail(url, width, height) do
    image_url = url <> "/image.jpg"
    {:ok, page} = Store.record_success(url, %{title: "Page", image_url: image_url})
    {:ok, pending} = Store.record_image_thumbnail_pending(page, image_url)

    key = "scraper/images/#{page.url_hash}/source-#{width}x#{height}.jpg"
    body = jpeg(width, height)
    MemoryStorage.put(key, body)

    {:ok, page} =
      Store.record_image_thumbnail_success(pending, %{
        source_url: image_url,
        storage_bucket: @bucket,
        storage_key: key,
        content_type: "image/jpeg",
        byte_size: byte_size(body),
        width: width,
        height: height
      })

    page
  end

  # Noise rather than a flat colour: a gradient compresses to almost nothing in
  # either format, and the size comparison would prove nothing.
  defp jpeg(width, height) do
    {:ok, noise} = Operation.gaussnoise(width, height, sigma: 40.0, mean: 128.0)
    {:ok, rgb} = Operation.bandjoin([noise, noise, noise])
    {:ok, rgb} = Operation.cast(rgb, :VIPS_FORMAT_UCHAR)
    {:ok, body} = VipsImage.write_to_buffer(rgb, ".jpg", Q: 82)
    body
  end
end
