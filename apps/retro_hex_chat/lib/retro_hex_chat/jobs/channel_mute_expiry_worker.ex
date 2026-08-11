defmodule RetroHexChat.Jobs.ChannelMuteExpiryWorker do
  @moduledoc """
  Expires temporary channel mutes.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "channel_mutes"],
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

  alias RetroHexChat.Channels.{Mutes, Server}
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) ::
          {:ok, :expired | :noop}
          | {:snooze, pos_integer()}
          | {:cancel, String.t()}
          | {:error, term()}
  def perform(%Oban.Job{args: %{"mute_id" => mute_id}}) do
    Observability.span(
      [:retro_hex_chat, :channels, :mutes, :expire],
      %{mute_id: mute_id},
      fn -> expire(WorkerArgs.positive_id(mute_id)) end,
      &ResultMetadata.expiry/1
    )
  end

  defp expire({:ok, mute_id}) do
    case Mutes.expire_due(mute_id) do
      {:ok, {:expired, mute}} ->
        Server.apply_channel_mute_expired(mute.channel_name, mute.target_nickname, mute.id)
        {:ok, :expired}

      {:ok, {:noop, _mute}} ->
        {:ok, :noop}

      {:ok, {:not_due, _mute, seconds}} ->
        {:snooze, seconds}

      {:error, :not_found} ->
        {:cancel, "channel mute not found"}

      {:error, :permanent_restriction} ->
        {:cancel, "channel mute is permanent"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp expire(:error), do: {:cancel, "invalid channel mute id"}
end
