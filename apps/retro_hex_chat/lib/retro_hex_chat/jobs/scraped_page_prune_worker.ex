defmodule RetroHexChat.Jobs.ScrapedPagePruneWorker do
  @moduledoc """
  Drops scraped pages nobody asks for any more.

  The archive keeps a page for 120 days, so it grows with every distinct link
  anyone posts or any feed publishes. Nothing used to remove them at all — the
  table this replaced had no pruning whatsoever and simply accumulated.

  Idle, not expired, is the test. An expired page that someone read this morning
  is about to be revalidated for free with a conditional request; deleting it
  would throw away the `etag` that makes that free and force a full download.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "scraper"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(1),
    cap_seconds: 15 * 60,
    step_seconds: 60

  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability
  alias RetroHexChat.Scraper.ImageCache
  alias RetroHexChat.Scraper.Store

  @default_limit 500

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :scraper, :prune],
      %{limit: limit},
      fn -> prune(limit) end,
      &prune_result_metadata/1
    )
  end

  @spec prune(pos_integer()) :: {:ok, map()}
  defp prune(limit) do
    summary = Store.prune(limit: limit)
    image_summary = ImageCache.delete_objects(summary.image_thumbnail_objects)
    {:ok, Map.put(summary, :image_thumbnail_delete, image_summary)}
  end

  @spec prune_result_metadata({:ok, map()}) :: map()
  defp prune_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      candidates: summary.candidates,
      deleted: summary.deleted,
      image_thumbnails_deleted: summary.image_thumbnail_delete.deleted,
      image_thumbnails_delete_failed: summary.image_thumbnail_delete.failed,
      oldest_expired_age_ms: summary.oldest_expired_age_ms
    }
  end
end
