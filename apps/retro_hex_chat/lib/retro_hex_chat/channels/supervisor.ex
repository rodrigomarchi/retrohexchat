defmodule RetroHexChat.Channels.Supervisor do
  @moduledoc """
  DynamicSupervisor for channel GenServer processes.
  One child process per active channel (Constitution III).
  """

  use RetroHexChat.ProcessSupervisor, child: RetroHexChat.Channels.Server

  @doc """
  The channel's process, started if it is not running. Losing a start race to
  another caller is not an error: the winner's process is the answer.
  """
  @spec ensure_started(String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_started(channel_name) do
    case RetroHexChat.Channels.Registry.lookup(channel_name) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        case start_child(channel_name) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
