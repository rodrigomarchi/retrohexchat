defmodule RetroHexChat.GroupCall.RoomFanout do
  @moduledoc """
  Who in a group-call room hears what: the members the room holds a seat for,
  and the pushes to their Phoenix channels.
  """

  alias RetroHexChat.GroupCall.RoomServer

  @doc "Everyone the room holds a seat for: the joined and those still connecting."
  @spec peer_states(RoomServer.state()) :: map()
  def peer_states(state) do
    Map.merge(state.participants, state.pending_participants)
  end

  @doc "Pushes `event` to every member's channel."
  @spec broadcast(RoomServer.state(), String.t(), map()) :: :ok
  def broadcast(state, event, payload) do
    state
    |> peer_states()
    |> Map.values()
    |> Enum.each(fn data ->
      send_channel_event(data.channel_pid, event, payload)
    end)
  end

  @doc "Pushes `event` to one member's channel, if it is still there."
  @spec send_channel_event(pid() | nil, String.t(), map()) :: :ok | nil
  def send_channel_event(channel_pid, event, payload) do
    if is_pid(channel_pid) and Process.alive?(channel_pid) do
      GenServer.cast(channel_pid, {:group_call_push, event, payload})
    end
  end
end
