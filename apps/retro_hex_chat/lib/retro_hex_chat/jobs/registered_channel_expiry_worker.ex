defmodule RetroHexChat.Jobs.RegisteredChannelExpiryWorker do
  @moduledoc """
  Durable maintenance worker for purging inactive registered channels.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "channels"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: :infinity
    ]

  alias RetroHexChat.Observability
  alias RetroHexChat.Services.ChanExpiry

  require Logger

  @timeout_ms 120_000

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(900, attempt * attempt * 30)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, ChanExpiry.purge_result()}
  def perform(%Oban.Job{}) do
    Observability.span(
      [:retro_hex_chat, :services, :channels, :expire],
      %{domain: "maintenance"},
      fn -> purge_channels() end,
      &result_metadata/1
    )
  end

  defp purge_channels do
    result = ChanExpiry.purge()

    Observability.set_current_span_attributes(result_metadata({:ok, result}))

    if result.purged_count > 0 do
      Logger.info(
        "registered_channel_expiry_stop candidates=#{result.candidate_count} purged=#{result.purged_count}"
      )
    end

    {:ok, result}
  end

  defp result_metadata({:ok, result}) do
    %{
      result: "ok",
      candidate_count: result.candidate_count,
      purged_count: result.purged_count,
      access_removed: result.access_removed,
      bans_removed: result.bans_removed,
      ban_exceptions_removed: result.ban_exceptions_removed,
      invite_exceptions_removed: result.invite_exceptions_removed,
      welcome_messages_removed: result.welcome_messages_removed
    }
  end
end
