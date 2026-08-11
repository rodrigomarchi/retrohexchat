defmodule RetroHexChat.Jobs.RegisteredNickExpiryWorker do
  @moduledoc """
  Durable maintenance worker for purging inactive registered nicknames.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "nicks"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: :infinity
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 15 * 60,
    step_seconds: 30

  alias RetroHexChat.Observability
  alias RetroHexChat.Services.NickExpiry

  require Logger

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, NickExpiry.purge_result()}
  def perform(%Oban.Job{}) do
    Observability.span(
      [:retro_hex_chat, :services, :nicks, :expire],
      %{domain: "maintenance"},
      fn -> purge_nicks() end,
      &result_metadata/1
    )
  end

  defp purge_nicks do
    result = NickExpiry.purge()

    Observability.set_current_span_attributes(result_metadata({:ok, result}))

    if result.purged_count > 0 do
      Logger.info(
        "registered_nick_expiry_stop candidates=#{result.candidate_count} purged=#{result.purged_count}"
      )
    end

    {:ok, result}
  end

  defp result_metadata({:ok, result}) do
    %{
      result: "ok",
      expired_count: result.expired_count,
      candidate_count: result.candidate_count,
      purged_count: result.purged_count,
      protected_identified_count: result.protected_identified_count,
      protected_admin_count: result.protected_admin_count,
      founder_promotions: result.founder_promotions,
      orphaned_channels_removed: result.orphaned_channels_removed,
      access_removed: result.access_removed,
      bans_removed: result.bans_removed,
      ban_exceptions_removed: result.ban_exceptions_removed,
      invite_exceptions_removed: result.invite_exceptions_removed,
      welcome_messages_removed: result.welcome_messages_removed
    }
  end
end
