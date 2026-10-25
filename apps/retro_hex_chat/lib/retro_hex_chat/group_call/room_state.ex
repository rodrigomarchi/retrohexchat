defmodule RetroHexChat.GroupCall.RoomState do
  @moduledoc """
  Reading a group-call room's state — which seat a participant holds, the
  channel membership the room stands on — and reporting what the room did.
  """

  alias RetroHexChat.Channels
  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.GroupCall.RoomServer

  @doc "The seat held for `participant_id`, and which map holds it: joined or still connecting."
  @spec participant_data(RoomServer.state(), integer()) ::
          {:ok, map(), :participants | :pending_participants} | {:error, :not_found}
  def participant_data(state, participant_id) do
    cond do
      data = state.participants[participant_id] ->
        {:ok, data, :participants}

      data = state.pending_participants[participant_id] ->
        {:ok, data, :pending_participants}

      true ->
        {:error, :not_found}
    end
  end

  @doc "The membership of the channel the room belongs to, read from the channel's process."
  @spec current_membership(RoomServer.state()) :: {:ok, Membership.t()} | {:error, term()}
  def current_membership(state) do
    with {:ok, channel_state} <- Channels.Server.get_state(state.room.channel_name) do
      {:ok, Membership.from_members(channel_state.members)}
    end
  end

  @doc "Reports a group-call event under `[:retro_hex_chat, :group_call, event]`."
  @spec telemetry(atom(), map(), map()) :: :ok
  def telemetry(event, measurements, metadata) do
    :telemetry.execute([:retro_hex_chat, :group_call, event], measurements, metadata)
  end
end
