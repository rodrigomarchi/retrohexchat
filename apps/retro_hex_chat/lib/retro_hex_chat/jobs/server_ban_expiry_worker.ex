defmodule RetroHexChat.Jobs.ServerBanExpiryWorker do
  @moduledoc """
  Durable maintenance worker for expiring time-limited server bans.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "server_bans"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: :infinity
    ]

  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Observability

  require Logger

  @timeout_ms 60_000

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(900, attempt * attempt * 30)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, non_neg_integer()}
  def perform(%Oban.Job{}) do
    Observability.span(
      [:retro_hex_chat, :admin, :server_bans, :expire],
      %{domain: "maintenance"},
      fn -> expire_bans() end,
      &result_metadata/1
    )
  end

  defp expire_bans do
    expired_count = ServerBans.expire_bans()

    Observability.set_current_span_attributes(%{expired_count: expired_count})

    if expired_count > 0 do
      Logger.info("server_ban_expiry_stop expired=#{expired_count}")
    end

    {:ok, expired_count}
  end

  defp result_metadata({:ok, expired_count}) do
    %{result: "ok", expired_count: expired_count}
  end
end
