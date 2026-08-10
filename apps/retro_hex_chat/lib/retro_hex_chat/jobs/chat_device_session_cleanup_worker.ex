defmodule RetroHexChat.Jobs.ChatDeviceSessionCleanupWorker do
  @moduledoc """
  Closes chat device session audit rows that stopped receiving heartbeats.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "trusted_devices", "sessions"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @timeout_ms 60_000
  @default_limit 100
  @default_stale_after_seconds 300

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(15 * 60, attempt * attempt * 60)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, TrustedDevices.stale_session_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    stale_after_seconds =
      WorkerArgs.positive_integer(args, "stale_after_seconds", @default_stale_after_seconds)

    Observability.span(
      [:retro_hex_chat, :trusted_devices, :session_cleanup],
      %{limit: limit, stale_after_seconds: stale_after_seconds},
      fn ->
        TrustedDevices.close_stale_sessions(
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
      candidates: summary.candidates,
      closed_sessions: summary.closed_sessions
    }
  end

  defp cleanup_result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
