defmodule RetroHexChat.Channels.Supervisor do
  @moduledoc """
  DynamicSupervisor for channel GenServer processes.
  One child process per active channel (Constitution III).
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

  @spec start_child(GenServer.server(), String.t()) :: DynamicSupervisor.on_start_child()
  def start_child(supervisor \\ __MODULE__, channel_name) do
    DynamicSupervisor.start_child(supervisor, {RetroHexChat.Channels.Server, channel_name})
  end

  @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def stop_child(supervisor \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end
end
