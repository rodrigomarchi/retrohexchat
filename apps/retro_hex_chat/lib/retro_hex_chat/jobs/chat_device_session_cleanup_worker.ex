# ex_dna:disable-for-next-line a worker's own query, telemetry event and summary keys on the shared worker shape
defmodule RetroHexChat.Jobs.ChatDeviceSessionCleanupWorker do
  @moduledoc """
  Closes chat device session audit rows that stopped receiving heartbeats.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["trusted_devices", "sessions"]

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @default_limit 100
  @default_stale_after_seconds 300

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
      ResultMetadata.summary([:candidates, :closed_sessions])
    )
  end
end
