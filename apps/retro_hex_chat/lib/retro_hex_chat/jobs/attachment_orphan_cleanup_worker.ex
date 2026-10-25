defmodule RetroHexChat.Jobs.AttachmentOrphanCleanupWorker do
  @moduledoc """
  Cleans reserved/uploaded attachment objects that never became chat attachments.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["attachments"],
    timeout: :timer.minutes(2)

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
      ResultMetadata.summary([:candidates, :deleted, :skipped, :bytes_deleted])
    )
  end
end
