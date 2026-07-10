defmodule RetroHexChat.GroupCall.PeerSupervisor do
  @moduledoc """
  DynamicSupervisor for per-participant WebRTC peer processes.
  """

  use DynamicSupervisor

  alias RetroHexChat.GroupCall.PeerServer

  @spec start_link(keyword()) :: DynamicSupervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_child(map()) :: DynamicSupervisor.on_start_child()
  @spec start_child(GenServer.server(), map()) :: DynamicSupervisor.on_start_child()
  def start_child(supervisor \\ __MODULE__, args) do
    DynamicSupervisor.start_child(supervisor, {PeerServer, args})
  end

  @spec terminate_peer(integer(), integer()) :: :ok
  def terminate_peer(room_id, participant_id) do
    case RetroHexChat.GroupCall.Registry.lookup_peer({:peer, room_id, participant_id}) do
      {:ok, pid} -> GenServer.stop(pid, :shutdown)
      {:error, :not_found} -> :ok
    end
  catch
    _exit_or_error, _reason -> :ok
  end
end
