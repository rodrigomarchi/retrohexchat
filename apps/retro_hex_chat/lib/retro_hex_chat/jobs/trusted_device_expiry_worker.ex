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

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Observability

  @timeout_ms 60_000
  @default_limit 100

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(15 * 60, attempt * attempt * 60)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, TrustedDevices.device_expiry_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = positive_arg(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :trusted_devices, :expire],
      %{limit: limit},
      fn -> TrustedDevices.expire_devices(limit: limit) end,
      &expiry_result_metadata/1
    )
  end

  defp positive_arg(args, key, default) do
    case Map.get(args, key) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
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

  defp expiry_result_metadata({:error, reason}) do
    %{result: "error", reason: error_reason(reason)}
  end

  defp error_reason(%Ecto.Changeset{}), do: "changeset_error"
  defp error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_reason(reason) when is_binary(reason), do: reason
  defp error_reason(%module{}), do: module |> Module.split() |> List.last()
  defp error_reason(_reason), do: "unknown"
end
