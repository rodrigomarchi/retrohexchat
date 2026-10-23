defmodule RetroHexChat.Channels.Supervisor do
  @moduledoc """
  DynamicSupervisor for channel GenServer processes.
  One child process per active channel (Constitution III).
  """

  # ex_dna:disable-for-lines:20 a DynamicSupervisor starts the same way wherever it is
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(strategy: :one_for_one, name: name)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec start_child(GenServer.server(), String.t()) :: DynamicSupervisor.on_start_child()
  def start_child(supervisor \\ __MODULE__, channel_name) do
    DynamicSupervisor.start_child(supervisor, {RetroHexChat.Channels.Server, channel_name})
  end

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

  @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def stop_child(supervisor \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end
end
