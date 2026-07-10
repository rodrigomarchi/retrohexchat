defmodule RetroHexChat.GroupCall.RoomSupervisor do
  @moduledoc """
  DynamicSupervisor for active group-call rooms.
  """

  use DynamicSupervisor

  alias RetroHexChat.GroupCall.RoomServer

  @spec start_link(keyword()) :: DynamicSupervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_child(String.t()) :: DynamicSupervisor.on_start_child()
  @spec start_child(GenServer.server(), String.t()) :: DynamicSupervisor.on_start_child()
  def start_child(supervisor \\ __MODULE__, room_token) do
    DynamicSupervisor.start_child(supervisor, {RoomServer, room_token})
  end

  @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def stop_child(supervisor \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end
end
