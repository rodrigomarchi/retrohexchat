defmodule RetroHexChat.Scraper.ImageCacheTest do
  @moduledoc """
  Thumbnail cache behaviour without real network or libvips work.
  """

  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Scraper.{Client, ImageCache, Store}

  @moduletag :integration

  @url "https://example.com/story"
  @image_url "https://cdn.example.com/story.jpg"

  defmodule StaticFetcher do
    @moduledoc false
    @behaviour RetroHexChat.Scraper.ImageFetcher

    @impl true
    def fetch(url, _opts) do
      {:ok, %{body: "original", content_type: "image/jpeg", final_url: url, byte_size: 8}}
    end
  end

  defmodule FailingFetcher do
    @moduledoc false
    @behaviour RetroHexChat.Scraper.ImageFetcher

    @impl true
    def fetch(_url, _opts), do: {:error, :unsupported_image_type}
  end

  defmodule FailingStorage do
    @moduledoc false
    @behaviour RetroHexChat.Chat.Attachments.Storage

    @impl true
    def put_file(_path, _key, _opts), do: {:error, :storage_unavailable}

    @impl true
    def delete_file(_bucket, _key, _opts), do: {:error, :storage_unavailable}

    @impl true
    def presigned_put_url(_bucket, _key, _opts), do: {:error, :storage_unavailable}

    @impl true
    def presigned_get_url(_bucket, _key, _opts), do: {:error, :storage_unavailable}
  end

  defmodule StaticThumbnailer do
    @moduledoc false
    @behaviour RetroHexChat.Scraper.ImageThumbnailer

    @impl true
    def thumbnail("original", _opts) do
      {:ok,
       %{
         body: "thumb",
         content_type: "image/jpeg",
         extension: "jpg",
         width: 640,
         height: 360,
         byte_size: 5
       }}
    end
  end

  setup do
    previous_cache = Application.get_env(:retro_hex_chat, :scraped_image_cache)
    previous_base_url = Application.get_env(:retro_hex_chat, :base_url)

    Application.put_env(:retro_hex_chat, :base_url, "https://chat.example.test")

    Application.put_env(:retro_hex_chat, :scraped_image_cache,
      storage: RetroHexChat.Chat.Attachments.TestStorage,
      fetcher: StaticFetcher,
      thumbnailer: StaticThumbnailer,
      bucket: "retrohexchat-uploads"
    )

    on_exit(fn ->
      restore_env(:scraped_image_cache, previous_cache)
      restore_env(:base_url, previous_base_url)
    end)

    :ok
  end

  describe "ensure_thumbnail/2" do
    test "downloads, thumbnails, stores and records a local image" do
      {:ok, page} =
        Store.record_success(@url, %{
          title: "Story",
          image_url: @image_url
        })

      assert {:ok, updated} = ImageCache.ensure_thumbnail(page)

      assert updated.image_thumbnail_status == "ready"
      assert updated.image_thumbnail_source_url == @image_url
      assert updated.image_thumbnail_storage_bucket == "retrohexchat-uploads"
      assert updated.image_thumbnail_storage_key =~ "scraper/images/"
      assert updated.image_thumbnail_content_type == "image/jpeg"
      assert updated.image_thumbnail_byte_size == 5
      assert updated.image_thumbnail_width == 640
      assert updated.image_thumbnail_height == 360
      assert updated.image_thumbnail_fetched_at

      assert ImageCache.public_url(updated) ==
               "https://chat.example.test/chat/scraped-pages/#{updated.url_hash}/thumbnail"

      metadata = Client.to_metadata(updated)

      assert metadata.cached_image == ImageCache.public_url(updated)
      assert metadata.original_image == @image_url
      assert metadata.image == metadata.cached_image
    end

    test "records deterministic image failures and leaves the remote image out of cached cards" do
      Application.put_env(:retro_hex_chat, :scraped_image_cache,
        storage: RetroHexChat.Chat.Attachments.TestStorage,
        fetcher: FailingFetcher,
        thumbnailer: StaticThumbnailer,
        bucket: "retrohexchat-uploads"
      )

      {:ok, page} =
        Store.record_success(@url, %{
          title: "Story",
          image_url: @image_url
        })

      assert {:error, :unsupported_image_type, updated} = ImageCache.ensure_thumbnail(page)

      assert updated.image_thumbnail_status == "failed"
      assert updated.image_thumbnail_error_reason == "unsupported_image_type"

      local_url = "https://chat.example.test/chat/scraped-pages/#{updated.url_hash}/thumbnail"
      assert ImageCache.public_url(updated) == local_url

      metadata = Client.to_metadata(updated)

      assert metadata.cached_image == local_url
      assert metadata.original_image == @image_url
      assert metadata.image == local_url
    end

    test "does not expose a placeholder before thumbnail generation has been attempted" do
      {:ok, page} =
        Store.record_success(@url, %{
          title: "Story",
          image_url: @image_url
        })

      assert ImageCache.public_url(page) == nil

      metadata = Client.to_metadata(page)

      refute Map.has_key?(metadata, :cached_image)
      assert metadata.image == @image_url
    end

    test "returns a placeholder response when a ready thumbnail cannot be signed" do
      Application.put_env(:retro_hex_chat, :scraped_image_cache,
        storage: FailingStorage,
        fetcher: StaticFetcher,
        thumbnailer: StaticThumbnailer,
        bucket: "retrohexchat-uploads"
      )

      {:ok, page} =
        Store.record_success(@url, %{
          title: "Story",
          image_url: @image_url
        })

      {:ok, page} =
        Store.record_image_thumbnail_success(page, %{
          source_url: @image_url,
          storage_bucket: "retrohexchat-uploads",
          storage_key: "scraper/images/story.jpg",
          content_type: "image/jpeg",
          byte_size: 42,
          width: 640,
          height: 360
        })

      assert {:ok, {:placeholder, "failed"}} = ImageCache.thumbnail_response(page.url_hash)
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)
end
