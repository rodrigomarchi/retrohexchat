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

  @doc """
  One edit to a Construct, whether it was made or why it was refused. The op's
  name is the measurement; its coordinates are not, because a tile is not a
  dimension anyone graphs.
  """
  @spec emit_construct_edit(String.t(), tuple(), :ok | atom()) :: :ok
  def emit_construct_edit(construct_id, op, result) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :construct, :edit],
      %{count: 1},
      %{channel: construct_id, op: elem(op, 0), result: result}
    )
  end
end
