defmodule RetroHexChat.Channels.Events do
  @moduledoc """
  Telemetry events for the Channels context.
  """

  @spec emit_channel_created(String.t()) :: :ok
  def emit_channel_created(channel_name) do
    :telemetry.execute(
      [:retro_hex_chat, :channels, :channel_created],
      %{count: 1},
      %{channel: channel_name}
    )
  end

  @spec emit_channel_destroyed(String.t()) :: :ok
  def emit_channel_destroyed(channel_name) do
    :telemetry.execute(
      [:retro_hex_chat, :channels, :channel_destroyed],
      %{count: 1},
      %{channel: channel_name}
    )
  end

  @spec emit_mode_changed(String.t(), String.t(), String.t()) :: :ok
  def emit_mode_changed(channel_name, modes, by) do
    :telemetry.execute(
      [:retro_hex_chat, :channels, :mode_changed],
      %{count: 1},
      %{channel: channel_name, modes: modes, by: by}
    )
  end

  @spec emit_topic_changed(String.t(), String.t(), String.t()) :: :ok
  def emit_topic_changed(channel_name, topic, by) do
    :telemetry.execute(
      [:retro_hex_chat, :channels, :topic_changed],
      %{count: 1},
      %{channel: channel_name, topic: topic, by: by}
    )
  end
end
