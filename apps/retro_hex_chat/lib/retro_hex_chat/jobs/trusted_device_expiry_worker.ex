# ex_dna:disable-for-next-line a worker's own query, telemetry event and summary keys on the shared worker shape
defmodule RetroHexChat.Jobs.TrustedDeviceExpiryWorker do
  @moduledoc """
  Materializes expired trusted devices as revoked by the system.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["trusted_devices"]

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @default_limit 100

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, TrustedDevices.device_expiry_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :trusted_devices, :expire],
      %{limit: limit},
      fn -> TrustedDevices.expire_devices(limit: limit) end,
      ResultMetadata.summary([:candidates, :expired_devices, :revoked_grants, :skipped])
    )
  end
end
