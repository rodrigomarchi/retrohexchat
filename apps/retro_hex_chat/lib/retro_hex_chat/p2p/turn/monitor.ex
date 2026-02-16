defmodule RetroHexChat.P2P.Turn.Monitor do
  @moduledoc false
  require Logger

  @spec start(pid(), :socket.socket()) :: :ok
  def start(pid, socket) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _object, _reason} ->
        Logger.info("Closing TURN socket #{inspect(socket)}")
        :ok = :socket.close(socket)
    end
  end
end
