defmodule RetroHexChat.GroupCall.PeerSupervisor do
  @moduledoc """
  DynamicSupervisor for per-participant WebRTC peer processes.
  """

  use RetroHexChat.ProcessSupervisor, child: RetroHexChat.GroupCall.PeerServer

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
