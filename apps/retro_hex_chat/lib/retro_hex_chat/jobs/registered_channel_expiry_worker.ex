# ex_dna:disable-for-next-line a worker's own query, telemetry event and summary keys on the shared worker shape
defmodule RetroHexChat.Jobs.RegisteredChannelExpiryWorker do
  @moduledoc """
  Durable maintenance worker for purging inactive registered channels.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["channels"],
    period: :infinity,
    timeout: :timer.minutes(2),
    step_seconds: 30

  alias RetroHexChat.Jobs.ExpirySweep
  alias RetroHexChat.Services.ChanExpiry

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, ChanExpiry.purge_result()}
  def perform(%Oban.Job{}),
    do: ExpirySweep.run(:channels, "registered_channel_expiry", &ChanExpiry.purge/0)
end
