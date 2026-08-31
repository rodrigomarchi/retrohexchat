defmodule RetroHexChat.Jobs.OpenLobbyExpiryWorker do
  @moduledoc """
  Closes the match links nobody followed.

  An open lobby is a seat anybody holding the address can take, so the deadline
  on it is a security property and not housekeeping: how long the link works is
  how long the exposure lasts. That makes this sweep part of the feature rather
  than maintenance of it, which is why it runs every few minutes instead of
  riding the hourly stale-record pass — that one exists for rows a *crashed
  process* left open, on a deliberately conservative 24-hour cutoff.

  Idempotent by construction: the condition is re-stated inside the write, so a
  lobby claimed between the listing and the update is reported `skipped` and
  left alone.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "open_lobby"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 5 * 60,
    step_seconds: 30

  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Lobby
  alias RetroHexChat.Observability

  @default_limit 200

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, Lobby.expiry_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :lobby, :open_expiry],
      %{limit: limit},
      fn -> Lobby.expire_open_sessions(limit: limit) end,
      &expiry_result_metadata/1
    )
  end

  defp expiry_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      open_lobby_candidates: summary.candidates,
      open_lobby_expired: summary.expired,
      open_lobby_skipped: summary.skipped,
      open_lobby_remaining: summary.remaining
    }
  end

  defp expiry_result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
