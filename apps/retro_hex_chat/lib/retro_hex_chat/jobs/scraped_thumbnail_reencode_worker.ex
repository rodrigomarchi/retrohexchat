defmodule RetroHexChat.Jobs.ScrapedThumbnailReencodeWorker do
  @moduledoc """
  Shrinks stored scraper thumbnails that are larger than the current frame.

  A thumbnail stays in Garage for as long as anyone reads its page, so changing
  the thumbnail format only shrinks the ones written afterwards; the rest keep
  their old size until they go idle. This walks them by id, one batch per job,
  and enqueues the next batch after a pause so the maintenance queue — which it
  shares with the prune — never waits behind it for long.

  Boot starts a walk from the beginning. Rows already converted no longer match,
  so a walk after the backlog is gone finds nothing and stops at its first job.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "scraper", "image"],
    # Unique per cursor: the running job enqueues its own successor, which a
    # worker-wide rule would reject as its duplicate. A boot during a walk can
    # therefore start a second one; both are safe to run, because a page is
    # claimed while converted and only moves if it still names its old object.
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:after_id],
      states: :incomplete,
      period: :infinity
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(3),
    cap_seconds: 15 * 60,
    step_seconds: 60

  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability
  alias RetroHexChat.Scraper.ImageCache

  require Logger

  @batch_size 200
  @pause_seconds 2

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    after_id = after_id(args)
    limit = WorkerArgs.positive_integer(args, "limit", @batch_size)

    Observability.span(
      [:retro_hex_chat, :scraper, :reencode],
      %{after_id: after_id, limit: limit},
      fn -> reencode(after_id, limit) end,
      &result_metadata/1
    )
  end

  # A walk starts at the beginning when it carries no cursor, which is what boot
  # and a manual enqueue both mean.
  @spec after_id(map()) :: non_neg_integer()
  defp after_id(args) do
    case WorkerArgs.positive_id(Map.get(args, "after_id")) do
      {:ok, id} -> id
      :error -> 0
    end
  end

  @spec reencode(non_neg_integer(), pos_integer()) :: {:ok, map()} | {:error, term()}
  defp reencode(after_id, limit) do
    summary = ImageCache.reencode_oversized(after_id: after_id, limit: limit)

    Logger.info(
      "scrape_image_reencode after_id=#{after_id} candidates=#{summary.candidates} " <>
        "reencoded=#{summary.reencoded} skipped=#{summary.skipped} " <>
        "bytes_deleted=#{summary.bytes_deleted}"
    )

    case schedule_next(summary, limit) do
      :ok -> {:ok, summary}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec schedule_next(map(), pos_integer()) :: :ok | {:error, term()}
  defp schedule_next(%{last_id: nil}, _limit), do: :ok

  defp schedule_next(%{last_id: last_id}, limit) do
    %{"after_id" => last_id, "limit" => limit}
    |> new(schedule_in: @pause_seconds)
    |> Jobs.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec result_metadata({:ok, map()} | {:error, term()}) :: map()
  defp result_metadata({:ok, summary}) do
    %{
      result: "ok",
      candidates: summary.candidates,
      skipped: summary.skipped,
      bytes_deleted: summary.bytes_deleted
    }
  end

  defp result_metadata({:error, reason}), do: %{result: "error", reason: inspect(reason)}
end
