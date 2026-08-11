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

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 15 * 60,
    step_seconds: 60

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @default_limit 100
  @default_orphan_age_seconds :timer.hours(1) |> div(1_000)

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
