defmodule RetroHexChat.VirtualSpace.Supervisor do
  @moduledoc """
  DynamicSupervisor for virtual space session GenServer processes.
  One child process per active session.
  """

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

  @spec start_child(String.t()) :: DynamicSupervisor.on_start_child()
  @spec start_child(GenServer.server(), String.t()) :: DynamicSupervisor.on_start_child()
  def start_child(supervisor \\ __MODULE__, token) do
    DynamicSupervisor.start_child(supervisor, {RetroHexChat.VirtualSpace.SessionServer, token})
  end

  @spec start_channel_child(String.t()) :: DynamicSupervisor.on_start_child()
  @spec start_channel_child(GenServer.server(), String.t()) :: DynamicSupervisor.on_start_child()
  def start_channel_child(supervisor \\ __MODULE__, channel_name) do
    DynamicSupervisor.start_child(
      supervisor,
      {RetroHexChat.VirtualSpace.SessionServer, {:channel, channel_name}}
    )
  end

  @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def stop_child(supervisor \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end
end
