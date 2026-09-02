defmodule RetroHexChat.Jobs.GlobalMuteExpiryWorker do
  @moduledoc """
  Expires temporary server-wide mutes.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "global_mutes"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:mute_id],
      states: :incomplete,
      period: :infinity
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.seconds(30),
    cap_seconds: 15 * 60,
    step_seconds: 30

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) ::
          {:ok, :expired | :noop}
          | {:snooze, pos_integer()}
          | {:cancel, String.t()}
          | {:error, term()}
  def perform(%Oban.Job{args: %{"mute_id" => mute_id}}) do
    Observability.span(
      [:retro_hex_chat, :admin, :global_mutes, :expire],
      %{mute_id: mute_id},
      fn -> expire(WorkerArgs.positive_id(mute_id)) end,
      &ResultMetadata.expiry/1
    )
  end

  defp expire({:ok, mute_id}) do
    case GlobalMutes.expire_due(mute_id) do
      {:ok, {:expired, mute}} ->
        broadcast_unmuted(mute.nickname)
        {:ok, :expired}

      {:ok, {:noop, _mute}} ->
        {:ok, :noop}

      {:ok, {:not_due, _mute, seconds}} ->
        {:snooze, seconds}

      {:error, :not_found} ->
        {:cancel, "global mute not found"}

      {:error, :permanent_restriction} ->
        {:cancel, "global mute is permanent"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp expire(:error), do: {:cancel, "invalid global mute id"}

  defp broadcast_unmuted(nickname) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      Topics.inbox(nickname),
      {:user_unmuted, %{nickname: nickname}}
    )
  end
end
