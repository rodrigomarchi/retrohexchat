defmodule RetroHexChat.Jobs.IgnoreExpiredCleanupWorker do
  @moduledoc """
  Removes expired durable ignore-list entries.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["ignore_list"]

  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @default_limit 500

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, IgnoreList.cleanup_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :chat, :ignore_list, :cleanup],
      %{limit: limit},
      fn -> IgnoreList.cleanup_expired_entries(limit: limit) end,
      ResultMetadata.summary([:candidates, :deleted, :oldest_expired_age_ms])
    )
  end
end
