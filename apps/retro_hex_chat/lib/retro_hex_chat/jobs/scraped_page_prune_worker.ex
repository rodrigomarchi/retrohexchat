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

  alias RetroHexChat.Observability
  alias RetroHexChat.Scraper.Store

  @timeout_ms 60_000
  @default_limit 500

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(15 * 60, attempt * attempt * 60)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()}
  def perform(%Oban.Job{args: args}) do
    limit = positive_arg(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :scraper, :prune],
      %{limit: limit},
      fn -> {:ok, Store.prune(limit: limit)} end,
      &prune_result_metadata/1
    )
  end

  @spec positive_arg(map(), String.t(), pos_integer()) :: pos_integer()
  defp positive_arg(args, key, default) do
    case Map.get(args, key) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
  end

  @spec prune_result_metadata({:ok, map()}) :: map()
  defp prune_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      candidates: summary.candidates,
      deleted: summary.deleted,
      oldest_expired_age_ms: summary.oldest_expired_age_ms
    }
  end
end
