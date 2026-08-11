defmodule RetroHexChat.Jobs.PageScrapeWorker do
  @moduledoc """
  Durable page scrape.

  Runs the fetch nobody wanted to wait for: a link posted in a channel is rendered
  immediately and filled in when this lands. The scrape itself, the retry
  classification and the storing all belong to `RetroHexChat.Scraper` — this is
  only the durable envelope around one call, so a scrape survives a restart and a
  transient failure comes back on its own.

  Unique by URL, so a link posted to five channels at once is fetched once.
  """

  use Oban.Worker,
    queue: :scrape,
    max_attempts: 3,
    tags: ["scraper"],
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
    timeout: :timer.seconds(20),
    cap_seconds: 5 * 60,
    step_seconds: 15

  alias RetroHexChat.Observability
  alias RetroHexChat.Scraper
  alias RetroHexChat.Scraper.Store

  require Logger

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, :fetched | :failed} | {:error, term()}
  def perform(%Oban.Job{args: %{"url" => url, "url_hash" => url_hash}} = job) do
    Observability.span(
      [:retro_hex_chat, :scraper, :fetch],
      %{url_hash: url_hash, attempt: job.attempt},
      fn -> scrape(url, job) end,
      &result_metadata/1
    )
  end

  @spec scrape(String.t(), Oban.Job.t()) :: {:ok, :fetched | :failed} | {:error, term()}
  defp scrape(url, %Oban.Job{} = job) do
    Logger.info("scrape_start url_hash=#{job.args["url_hash"]} attempt=#{job.attempt}")

    case Scraper.fetch(url, attempt: job.attempt) do
      {:ok, page} ->
        Observability.set_current_span_attributes(%{result: "ok", status: page.status})
        Logger.info("scrape_stop url_hash=#{page.url_hash} result=ok status=#{page.status}")
        {:ok, :fetched}

      {:error, reason} ->
        settle(url, reason, job)
    end
  end

  # A failure the store already recorded as retryable is handed back to Oban so it
  # comes round again; anything else is this URL's answer for now. Asking the
  # store rather than re-deciding here keeps one definition of "worth retrying".
  @spec settle(String.t(), term(), Oban.Job.t()) :: {:ok, :failed} | {:error, term()}
  defp settle(url, reason, %Oban.Job{} = job) do
    if Store.retryable_error?(reason) and job.attempt < job.max_attempts do
      Logger.warning(
        "scrape_retry url_hash=#{job.args["url_hash"]} " <>
          "reason=#{Store.error_reason(reason)} attempt=#{job.attempt}"
      )

      {:error, reason}
    else
      _ = announce_final(url)

      Logger.info(
        "scrape_stop url_hash=#{job.args["url_hash"]} result=failed " <>
          "reason=#{Store.error_reason(reason)} attempt=#{job.attempt}"
      )

      {:ok, :failed}
    end
  end

  # The row is already written; what is left is telling the readers who are still
  # showing a spinner that no title is coming.
  @spec announce_final(String.t()) :: :ok
  defp announce_final(url) do
    case Store.get_by_url(url) do
      nil -> :ok
      page -> Scraper.cache_and_announce(page)
    end
  end

  @spec result_metadata({:ok, :fetched | :failed} | {:error, term()}) :: map()
  defp result_metadata({:ok, :fetched}), do: %{result: "ok"}
  defp result_metadata({:ok, :failed}), do: %{result: "failed"}
  defp result_metadata({:error, reason}), do: %{result: "retry", reason: log_reason(reason)}

  @spec log_reason(term()) :: String.t()
  defp log_reason(%Ecto.Changeset{}), do: "changeset_error"
  defp log_reason(reason), do: Store.error_reason(reason)
end
