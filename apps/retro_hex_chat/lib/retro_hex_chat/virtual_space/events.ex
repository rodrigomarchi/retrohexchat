defmodule RetroHexChat.VirtualSpace.Events do
  @moduledoc """
  Telemetry events for the VirtualSpace context.
  """

  alias RetroHexChat.VirtualSpace.Construct

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
      %{channel: construct_id, room: room(construct_id), op: elem(op, 0), result: result}
    )
  end

  @doc """
  Somebody pressed E on a piece in a Construct: which kind, and whether it
  did something or why it did not.
  """
  @spec emit_construct_use(String.t(), String.t(), :ok | atom()) :: :ok
  def emit_construct_use(construct_id, kind, result) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :construct, :use],
      %{count: 1},
      %{channel: construct_id, room: room(construct_id), kind: kind, result: result}
    )
  end

  # Which room behind a gate it was — the Construct, the Office or the Game
  # Room — so a graph can tell them apart.
  defp room(construct_id) do
    case Construct.kind(construct_id) do
      {:ok, kind} -> kind
      :error -> :unknown
    end
  end
end
