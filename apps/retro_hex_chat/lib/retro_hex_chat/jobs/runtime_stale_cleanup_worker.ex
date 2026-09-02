defmodule RetroHexChat.Jobs.RuntimeStaleCleanupWorker do
  @moduledoc """
  Reconciles abandoned runtime lifecycle records through Oban.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "runtime_stale"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 15 * 60,
    step_seconds: 60

  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability
  alias RetroHexChat.RuntimeStaleCleanup

  @default_limit 100

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, RuntimeStaleCleanup.summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    stale_after_seconds =
      WorkerArgs.positive_integer(
        args,
        "stale_after_seconds",
        RuntimeStaleCleanup.default_stale_after_seconds()
      )

    Observability.span(
      [:retro_hex_chat, :runtime, :stale_cleanup],
      %{limit: limit, stale_after_seconds: stale_after_seconds},
      fn ->
        RuntimeStaleCleanup.cleanup(
          limit: limit,
          stale_after_seconds: stale_after_seconds
        )
      end,
      &cleanup_result_metadata/1
    )
  end

  defp cleanup_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      lobby_candidates: summary.lobby.candidates,
      lobby_expired: summary.lobby.expired,
      lobby_skipped: summary.lobby.skipped,
      arcade_candidates: summary.arcade.candidates,
      arcade_expired: summary.arcade.expired,
      arcade_skipped: summary.arcade.skipped,
      group_call_candidates: summary.group_call.candidates,
      group_call_expired: summary.group_call.expired,
      group_call_skipped: summary.group_call.skipped,
      space_candidates: summary.space.candidates,
      space_expired: summary.space.expired,
      space_skipped: summary.space.skipped
    }
  end

  defp cleanup_result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
