defmodule RetroHexChat.Jobs.ScrapedImageWorker do
  @moduledoc """
  Durable thumbnail generation for scraped page images.
  """

  use Oban.Worker,
    queue: :scrape,
    max_attempts: 3,
    tags: ["scraper", "image"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:url_hash],
      states: :incomplete,
      period: :infinity
    ],
    replace: [
      available: [:scheduled_at],
      scheduled: [:scheduled_at]
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.seconds(30),
    cap_seconds: 5 * 60,
    step_seconds: 15

  alias RetroHexChat.Net.HTTPRetry
  alias RetroHexChat.Observability
  alias RetroHexChat.Scraper.ImageCache
  alias RetroHexChat.Scraper.ScrapedPage
  alias RetroHexChat.Scraper.Store

  require Logger

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  def perform(%Oban.Job{args: %{"url_hash" => url_hash}} = job) do
    Observability.span(
      [:retro_hex_chat, :scraper, :image],
      %{url_hash: url_hash, attempt: job.attempt},
      fn -> do_perform(url_hash, job) end,
      &result_metadata/1
    )
  end

  @spec do_perform(String.t(), Oban.Job.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  defp do_perform(url_hash, job) do
    Logger.info("scrape_image_start url_hash=#{url_hash} attempt=#{job.attempt}")

    case Store.get_by_hash(url_hash) do
      nil ->
        {:cancel, "scraped page not found"}

      %ScrapedPage{} = page ->
        generate(page, job)
    end
  end

  @spec generate(ScrapedPage.t(), Oban.Job.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  defp generate(%ScrapedPage{} = page, %Oban.Job{} = job) do
    case ImageCache.ensure_thumbnail(page,
           enqueue_on_failure?: false,
           retryable_failure_status: retryable_failure_status(job)
         ) do
      {:ok, updated} ->
        Logger.info("scrape_image_stop url_hash=#{updated.url_hash} result=ok")
        :ok

      {:error, reason, updated} ->
        settle(updated, reason, job)
    end
  end

  @spec settle(ScrapedPage.t(), term(), Oban.Job.t()) ::
          {:cancel, String.t()} | {:error, term()}
  defp settle(%ScrapedPage{} = page, reason, %Oban.Job{} = job) do
    if retryable?(reason) and job.attempt < job.max_attempts do
      Logger.warning(
        "scrape_image_retry url_hash=#{page.url_hash} " <>
          "reason=#{Store.error_reason(reason)} attempt=#{job.attempt}"
      )

      {:error, reason}
    else
      Logger.info(
        "scrape_image_stop url_hash=#{page.url_hash} result=failed " <>
          "reason=#{Store.error_reason(reason)} attempt=#{job.attempt}"
      )

      {:cancel, Store.error_reason(reason)}
    end
  end

  @spec retryable_failure_status(Oban.Job.t()) :: String.t()
  defp retryable_failure_status(%Oban.Job{} = job) do
    if job.attempt < job.max_attempts, do: "pending", else: "failed"
  end

  @spec retryable?(term()) :: boolean()
  defp retryable?({:storage_failed, _reason}), do: true
  defp retryable?(reason), do: HTTPRetry.retryable?(reason)

  @spec result_metadata(:ok | {:cancel, String.t()} | {:error, term()}) :: map()
  defp result_metadata(:ok), do: %{result: "ok"}
  defp result_metadata({:cancel, reason}), do: %{result: "failed", reason: reason}

  defp result_metadata({:error, reason}),
    do: %{result: "retry", reason: Store.error_reason(reason)}
end
