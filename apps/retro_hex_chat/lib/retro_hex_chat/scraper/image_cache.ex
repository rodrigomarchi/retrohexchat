defmodule RetroHexChat.Scraper.ImageCache do
  @moduledoc """
  Local thumbnail cache for images discovered by the page scraper.

  The page row keeps the publisher's original `image_url`; this module creates a
  small local derivative in Garage and exposes it through a stable application
  URL. Cards can then embed the app URL instead of a remote publisher image or a
  presigned URL that would expire inside persisted chat history.
  """

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.ScrapedImageWorker
  alias RetroHexChat.Net.HTTPRetry
  alias RetroHexChat.Scraper.{Cache, HTTPImageFetcher, ScrapedPage, Store, VixImageThumbnailer}

  require Logger

  @thumb_width 640
  @thumb_height 360
  @signed_url_ttl_seconds 300

  @type delete_summary :: %{
          attempted: non_neg_integer(),
          deleted: non_neg_integer(),
          failed: non_neg_integer()
        }
  @type thumbnail_response :: {:redirect, String.t()} | {:placeholder, String.t()}

  @doc "Whether `page` already has a current local thumbnail."
  @spec ready?(ScrapedPage.t()) :: boolean()
  def ready?(%ScrapedPage{} = page) do
    page.image_thumbnail_status == "ready" and
      present?(page.image_url) and
      page.image_thumbnail_source_url == page.image_url and
      present?(page.image_thumbnail_storage_bucket) and
      present?(page.image_thumbnail_storage_key)
  end

  @doc "Stable absolute URL for the local thumbnail or its placeholder."
  @spec public_url(ScrapedPage.t()) :: String.t() | nil
  def public_url(%ScrapedPage{} = page) do
    if routable?(page), do: "#{base_url()}/chat/scraped-pages/#{page.url_hash}/thumbnail"
  end

  @doc "What the public thumbnail route should serve for `url_hash`."
  @spec thumbnail_response(String.t(), keyword()) ::
          {:ok, thumbnail_response()} | {:error, term()}
  def thumbnail_response(url_hash, opts \\ []) when is_binary(url_hash) do
    expires_in = Keyword.get(opts, :expires_in, @signed_url_ttl_seconds)

    case Store.get_by_hash(url_hash) do
      %ScrapedPage{} = page -> thumbnail_response_for(page, expires_in)
      _other -> {:error, :not_found}
    end
  end

  @doc """
  Ensures `page` has a current thumbnail, doing the work on the caller process.

  Failure is recorded on the row and returned with the freshest row. Callers on a
  delivery path can still publish the card without falling back to the remote
  image.
  """
  @spec ensure_thumbnail(ScrapedPage.t(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, term(), ScrapedPage.t()}
  def ensure_thumbnail(%ScrapedPage{} = page, opts \\ []) do
    cond do
      ready?(page) ->
        {:ok, page}

      not present?(page.image_url) ->
        {:ok, page}

      true ->
        with_claim(page, opts)
    end
  end

  @doc "Enqueues a durable thumbnail job when the page has an image worth caching."
  @spec request(ScrapedPage.t()) :: :ok | {:error, term()}
  def request(%ScrapedPage{} = page) do
    cond do
      ready?(page) ->
        :ok

      not present?(page.image_url) ->
        :ok

      page.image_thumbnail_status == "failed" and
          page.image_thumbnail_source_url == page.image_url ->
        :ok

      true ->
        enqueue(page)
    end
  end

  @spec routable?(ScrapedPage.t()) :: boolean()
  defp routable?(%ScrapedPage{} = page) do
    page.image_thumbnail_status in ["ready", "pending", "failed"] and
      page.image_thumbnail_source_url == page.image_url and
      present?(page.image_url)
  end

  @spec placeholder_status(ScrapedPage.t()) :: String.t()
  defp placeholder_status(%ScrapedPage{image_thumbnail_status: "failed"}), do: "failed"
  defp placeholder_status(%ScrapedPage{image_thumbnail_status: "pending"}), do: "pending"
  defp placeholder_status(_page), do: "unavailable"

  @spec thumbnail_response_for(ScrapedPage.t(), pos_integer()) ::
          {:ok, thumbnail_response()} | {:error, term()}
  defp thumbnail_response_for(%ScrapedPage{} = page, expires_in) do
    cond do
      not routable?(page) -> {:error, :not_found}
      ready?(page) -> signed_thumbnail_response(page, expires_in)
      true -> {:ok, {:placeholder, placeholder_status(page)}}
    end
  end

  @spec signed_thumbnail_response(ScrapedPage.t(), pos_integer()) ::
          {:ok, thumbnail_response()} | {:error, term()}
  defp signed_thumbnail_response(%ScrapedPage{} = page, expires_in) do
    case storage().presigned_get_url(
           page.image_thumbnail_storage_bucket,
           page.image_thumbnail_storage_key,
           expires_in: expires_in
         ) do
      {:ok, url} ->
        {:ok, {:redirect, url}}

      {:error, reason} ->
        Logger.warning(
          "scrape_image_download_url_error url_hash=#{page.url_hash} reason=#{inspect(reason)}"
        )

        {:ok, {:placeholder, "failed"}}
    end
  end

  @doc "Deletes Garage objects that belonged to pruned scraped pages."
  @spec delete_objects([Store.image_thumbnail_object()]) :: delete_summary()
  def delete_objects(objects) when is_list(objects) do
    Enum.reduce(objects, %{attempted: 0, deleted: 0, failed: 0}, fn object, summary ->
      delete_object(object, summary)
    end)
  end

  @spec with_claim(ScrapedPage.t(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, term(), ScrapedPage.t()}
  defp with_claim(%ScrapedPage{} = page, opts) do
    claim = "image:#{page.url_hash}"

    case Cache.claim(claim) do
      :ok ->
        try do
          generate(page, opts)
        after
          Cache.release(claim)
        end

      :taken ->
        latest = Store.get_by_hash(page.url_hash) || page
        {:ok, latest}
    end
  end

  @spec generate(ScrapedPage.t(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, term(), ScrapedPage.t()}
  defp generate(%ScrapedPage{} = page, opts) do
    source_url = page.image_url

    case do_generate(page, source_url, opts) do
      {:ok, updated} ->
        Cache.put(updated)
        {:ok, updated}

      {:error, reason} ->
        record_failure(page, source_url, reason, opts)
    end
  end

  @spec do_generate(ScrapedPage.t(), String.t(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, term()}
  defp do_generate(page, source_url, opts) do
    with {:ok, pending} <- Store.record_image_thumbnail_pending(page, source_url),
         {:ok, fetched} <- fetcher().fetch(source_url, opts),
         {:ok, thumbnail} <-
           thumbnailer().thumbnail(fetched.body, width: @thumb_width, height: @thumb_height),
         {:ok, stored} <- put_thumbnail(pending, source_url, thumbnail),
         {:ok, updated} <- Store.record_image_thumbnail_success(pending, stored) do
      {:ok, updated}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec record_failure(ScrapedPage.t(), String.t(), term(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, term(), ScrapedPage.t()}
  defp record_failure(page, source_url, reason, opts) do
    status =
      if retryable?(reason),
        do: Keyword.get(opts, :retryable_failure_status, "pending"),
        else: "failed"

    case Store.record_image_thumbnail_failure(page, source_url, reason, status: status) do
      {:ok, updated} ->
        Cache.put(updated)
        maybe_enqueue_after_failure(updated, reason, opts)
        {:error, reason, updated}

      {:error, changeset} ->
        {:error, changeset, page}
    end
  end

  @spec maybe_enqueue_after_failure(ScrapedPage.t(), term(), keyword()) :: :ok | {:error, term()}
  defp maybe_enqueue_after_failure(page, reason, opts) do
    if retryable?(reason) and Keyword.get(opts, :enqueue_on_failure?, true) do
      request(page)
    else
      :ok
    end
  end

  @spec put_thumbnail(ScrapedPage.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  defp put_thumbnail(page, source_url, thumbnail) do
    key = object_key(page, source_url, thumbnail.extension)
    path = temp_path(thumbnail.extension)

    try do
      with :ok <- File.write(path, thumbnail.body),
           {:ok, stored} <-
             storage().put_file(path, key,
               bucket: bucket(),
               content_type: thumbnail.content_type,
               byte_size: thumbnail.byte_size
             ) do
        {:ok,
         %{
           source_url: source_url,
           storage_bucket: Map.get(stored, :bucket) || bucket(),
           storage_key: Map.get(stored, :key) || key,
           content_type: thumbnail.content_type,
           byte_size: thumbnail.byte_size,
           width: thumbnail.width,
           height: thumbnail.height
         }}
      else
        {:error, reason} -> {:error, {:storage_failed, reason}}
      end
    after
      File.rm(path)
    end
  end

  @spec enqueue(ScrapedPage.t()) :: :ok | {:error, term()}
  defp enqueue(%ScrapedPage{} = page) do
    case Jobs.insert(ScrapedImageWorker.new(%{url_hash: page.url_hash})) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.warning("scrape_image_request_error reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec delete_object(Store.image_thumbnail_object(), delete_summary()) :: delete_summary()
  defp delete_object(%{bucket: bucket, key: key}, summary) do
    case storage().delete_file(bucket, key, []) do
      :ok ->
        %{summary | attempted: summary.attempted + 1, deleted: summary.deleted + 1}

      {:error, reason} ->
        Logger.warning("scrape_image_delete_error key=#{key} reason=#{inspect(reason)}")
        %{summary | attempted: summary.attempted + 1, failed: summary.failed + 1}
    end
  end

  defp delete_object(_object, summary), do: summary

  @spec retryable?(term()) :: boolean()
  defp retryable?({:storage_failed, _reason}), do: true
  defp retryable?(reason), do: HTTPRetry.retryable?(reason)

  @spec object_key(ScrapedPage.t(), String.t(), String.t()) :: String.t()
  defp object_key(%ScrapedPage{url_hash: url_hash}, source_url, extension) do
    date = Date.utc_today()
    source_hash = :sha256 |> :crypto.hash(source_url) |> Base.encode16(case: :lower)

    [
      "scraper",
      "images",
      date.year,
      pad(date.month),
      pad(date.day),
      url_hash,
      "#{source_hash}-#{@thumb_width}x#{@thumb_height}.#{extension}"
    ]
    |> Enum.map(&to_string/1)
    |> Path.join()
  end

  @spec temp_path(String.t()) :: Path.t()
  defp temp_path(extension) do
    Path.join(System.tmp_dir!(), "retrohex-scrape-thumb-#{Ecto.UUID.generate()}.#{extension}")
  end

  @spec pad(pos_integer()) :: String.t()
  defp pad(value) when value < 10, do: "0#{value}"
  defp pad(value), do: Integer.to_string(value)

  @spec base_url() :: String.t()
  defp base_url do
    :retro_hex_chat
    |> Application.get_env(:base_url, "http://localhost:4000")
    |> String.trim()
    |> String.trim_trailing("/")
  end

  @spec storage() :: module()
  defp storage, do: Keyword.fetch!(config(), :storage)

  @spec fetcher() :: module()
  defp fetcher, do: Keyword.get(config(), :fetcher, HTTPImageFetcher)

  @spec thumbnailer() :: module()
  defp thumbnailer, do: Keyword.get(config(), :thumbnailer, VixImageThumbnailer)

  @spec bucket() :: String.t()
  defp bucket, do: Keyword.get(config(), :bucket, Attachments.bucket())

  @spec config() :: keyword()
  defp config do
    :retro_hex_chat
    |> Application.get_env(:chat_uploads, [])
    |> Keyword.merge(Application.get_env(:retro_hex_chat, :scraped_image_cache, []))
  end

  @spec present?(String.t() | nil) :: boolean()
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
