defmodule RetroHexChat.Jobs.TrustedDeviceExpiryWorker do
  @moduledoc """
  Materializes expired trusted devices as revoked by the system.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "trusted_devices"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(1),
    cap_seconds: 15 * 60,
    step_seconds: 60

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
      &expiry_result_metadata/1
    )
  end

  defp expiry_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      candidates: summary.candidates,
      expired_devices: summary.expired_devices,
      revoked_grants: summary.revoked_grants,
      skipped: summary.skipped
    }
  end

  defp expiry_result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
