defmodule RetroHexChat.Jobs.GameChallengeWorker do
  @moduledoc """
  Turns the week's challenge in every game's channel, early on Monday.

  Weekly only, and not at boot: it speaks in public channels, and a deploy in
  the middle of the week would open the same challenge twice.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    tags: ["maintenance", "games"],
    unique: [fields: [:worker, :args], period: 86_400]

  alias RetroHexChat.Games.Challenges
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Observability

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()} | {:error, term()}
  def perform(%Oban.Job{}) do
    Observability.span(
      [:retro_hex_chat, :games, :challenge, :turn],
      %{},
      fn -> Challenges.turn_week(Date.utc_today()) end,
      &result_metadata/1
    )
  end

  @spec result_metadata({:ok, map()} | {:error, term()}) :: map()
  defp result_metadata({:ok, %{posted: posted}}), do: %{result: "ok", messages_sent: posted}
  defp result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
