defmodule RetroHexChat.Jobs.ChannelMuteExpiryWorker do
  @moduledoc """
  Expires temporary channel mutes.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["channel_mutes"],
    unique_fields: [:worker, :queue, :args],
    unique_keys: [:mute_id],
    period: :infinity,
    timeout: :timer.seconds(30),
    step_seconds: 30

  alias RetroHexChat.Channels.{Mutes, Server}
  alias RetroHexChat.Jobs.MuteExpiry

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: MuteExpiry.outcome()
  def perform(%Oban.Job{args: %{"mute_id" => mute_id}}),
    do:
      MuteExpiry.run(
        [:retro_hex_chat, :channels, :mutes, :expire],
        "channel mute",
        mute_id,
        &Mutes.expire_due/1,
        &Server.apply_channel_mute_expired(&1.channel_name, &1.target_nickname, &1.id)
      )
end
