# ex_dna:disable-for-next-line a worker's own query, telemetry event and summary keys on the shared worker shape
defmodule RetroHexChat.Jobs.RegisteredNickExpiryWorker do
  @moduledoc """
  Durable maintenance worker for purging inactive registered nicknames.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["nicks"],
    period: :infinity,
    timeout: :timer.minutes(2),
    step_seconds: 30

  alias RetroHexChat.Jobs.ExpirySweep
  alias RetroHexChat.Services.NickExpiry

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, NickExpiry.purge_result()}
  def perform(%Oban.Job{}),
    do: ExpirySweep.run(:nicks, "registered_nick_expiry", &NickExpiry.purge/0)
end
