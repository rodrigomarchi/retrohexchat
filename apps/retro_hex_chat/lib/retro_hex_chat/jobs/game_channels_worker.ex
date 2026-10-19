defmodule RetroHexChat.Jobs.GameChannelsWorker do
  @moduledoc """
  Makes sure every Retro Game has its channel, with GameServ inside.

  Runs at boot and every hour. The hour is what a deploy relies on: `@reboot`
  fires only on the node leading Oban, and while a release rolls out that is
  the node going away. A new game in the catalogue gets its channel within the
  hour of the deploy that ships it, and a channel process that started without
  the service — after a crash, or because a visitor's watch started it — gets
  it back. Creating is idempotent, so running twice is the same as once.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "games"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(1),
    cap_seconds: 15 * 60,
    step_seconds: 60

  alias RetroHexChat.Games.Channels
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Observability

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()} | {:error, term()}
  def perform(%Oban.Job{}) do
    Observability.span(
      [:retro_hex_chat, :games, :channels, :ensure],
      %{},
      &Channels.ensure_all/0,
      &result_metadata/1
    )
  end

  @spec result_metadata({:ok, map()} | {:error, term()}) :: map()
  defp result_metadata({:ok, summary}),
    do: %{result: "ok", candidates: summary.channels, published_count: summary.created}

  defp result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
