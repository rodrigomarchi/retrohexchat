defmodule RetroHexChat.Jobs.GameDigestWorker do
  @moduledoc """
  Says yesterday's digest in every game channel that had a match, and in
  every arcade game's channel that had a play.

  Daily only, and deliberately not at boot: the digest is a line in a public
  channel, and a deploy in the middle of the day would say yesterday a second
  time. A day the cron misses goes without a digest, which nobody is owed.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    tags: ["maintenance", "games"],
    unique: [fields: [:worker, :args], period: 86_400]

  alias RetroHexChat.Arcade.Digest, as: ArcadeDigest
  alias RetroHexChat.Games.Digest
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Observability

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    date =
      case args do
        %{"date" => iso} -> Date.from_iso8601!(iso)
        _yesterday -> Date.add(Date.utc_today(), -1)
      end

    Observability.span(
      [:retro_hex_chat, :games, :digest, :post],
      %{},
      fn -> post(date) end,
      &result_metadata/1
    )
  end

  defp post(date) do
    {:ok, %{posted: games}} = Digest.post(date)
    {:ok, %{posted: arcade}} = ArcadeDigest.post(date)
    {:ok, %{posted: games + arcade}}
  end

  @spec result_metadata({:ok, map()} | {:error, term()}) :: map()
  defp result_metadata({:ok, %{posted: posted}}), do: %{result: "ok", messages_sent: posted}
  defp result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
