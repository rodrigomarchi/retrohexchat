defmodule RetroHexChat.Jobs.LinkPreviewFetchWorker do
  @moduledoc """
  Drains scrape jobs enqueued before this worker was renamed.

  **Delete this module, and the `:link_preview` queue in `config/config.exs`, once
  one deploy has passed.** It exists only to keep a rename from stranding work.

  Oban stores `queue` and `worker` as plain strings on the job row, so a job
  enqueued by the previous release names a module that no longer exists. Removing
  the queue at the same time would orphan every `available`, `scheduled` and
  `retryable` row: nothing would run them, nothing would fail them, and
  `ObanHealth` would count them for ever.

  Nothing new is ever enqueued here — `RetroHexChat.Scraper.request/1` enqueues
  `RetroHexChat.Jobs.PageScrapeWorker`. This clause only finishes what the
  previous release started.
  """

  use Oban.Worker,
    queue: :link_preview,
    max_attempts: 3,
    tags: ["scraper", "deprecated"]

  alias RetroHexChat.Jobs.PageScrapeWorker

  require Logger

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  defdelegate timeout(job), to: PageScrapeWorker

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  defdelegate backoff(job), to: PageScrapeWorker

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, :fetched | :failed} | {:error, term()}
  def perform(%Oban.Job{} = job) do
    Logger.info("scrape_legacy_job id=#{job.id} url_hash=#{job.args["url_hash"]}")
    PageScrapeWorker.perform(job)
  end
end
