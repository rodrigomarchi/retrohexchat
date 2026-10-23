defmodule RetroHexChat.Jobs.GlobalMuteExpiryWorker do
  @moduledoc """
  Expires temporary server-wide mutes.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["global_mutes"],
    unique_fields: [:worker, :queue, :args],
    unique_keys: [:mute_id],
    period: :infinity,
    timeout: :timer.seconds(30),
    step_seconds: 30

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Jobs.MuteExpiry
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: MuteExpiry.outcome()
  def perform(%Oban.Job{args: %{"mute_id" => mute_id}}),
    do:
      MuteExpiry.run(
        [:retro_hex_chat, :admin, :global_mutes, :expire],
        "global mute",
        mute_id,
        &GlobalMutes.expire_due/1,
        &broadcast_unmuted(&1.nickname)
      )

  defp broadcast_unmuted(nickname) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      Topics.inbox(nickname),
      {:user_unmuted, %{nickname: nickname}}
    )
  end
end
