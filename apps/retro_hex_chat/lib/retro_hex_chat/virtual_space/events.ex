defmodule RetroHexChat.VirtualSpace.Events do
  @moduledoc """
  Telemetry events for the VirtualSpace context.
  """

  @spec emit_participant_count(String.t(), non_neg_integer()) :: :ok
  def emit_participant_count(channel_name, count) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :participant_count],
      %{value: count},
      %{channel: channel_name}
    )
  end

  @spec emit_step(String.t(), :accepted | :rejected, atom(), integer()) :: :ok
  def emit_step(channel_name, result, reason, duration) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :step],
      %{count: 1, duration: duration},
      %{channel: channel_name, result: result, reason: reason}
    )
  end
end
