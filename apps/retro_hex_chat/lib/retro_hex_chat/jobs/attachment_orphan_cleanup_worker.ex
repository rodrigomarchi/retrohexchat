defmodule RetroHexChat.Jobs.AttachmentOrphanCleanupWorker do
  @moduledoc """
  Cleans reserved/uploaded attachment objects that never became chat attachments.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "attachments"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @timeout_ms 120_000
  @default_limit 100
  @default_orphan_age_seconds :timer.hours(1) |> div(1_000)

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(15 * 60, attempt * attempt * 60)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, Attachments.cleanup_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    orphan_age_seconds =
      WorkerArgs.positive_integer(args, "orphan_age_seconds", @default_orphan_age_seconds)

    Observability.span(
      [:retro_hex_chat, :attachments, :orphan_cleanup],
      %{limit: limit, orphan_age_seconds: orphan_age_seconds},
      fn ->
        Attachments.cleanup_orphan_uploads(
          limit: limit,
          orphan_age_seconds: orphan_age_seconds
        )
      end,
      &cleanup_result_metadata/1
    )
  end

  defp cleanup_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      candidates: summary.candidates,
      deleted: summary.deleted,
      skipped: summary.skipped,
      bytes_deleted: summary.bytes_deleted
    }
  end

  defp cleanup_result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
