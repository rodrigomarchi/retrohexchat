defmodule RetroHexChat.VirtualSpace.Supervisor do
  @moduledoc """
  DynamicSupervisor for virtual space runtime GenServer processes.
  One child process per viewed channel space.
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

  @spec start_channel_child(String.t()) :: DynamicSupervisor.on_start_child()
  @spec start_channel_child(GenServer.server(), String.t()) :: DynamicSupervisor.on_start_child()
  def start_channel_child(supervisor \\ __MODULE__, channel_name) do
    DynamicSupervisor.start_child(
      supervisor,
      {RetroHexChat.VirtualSpace.ChannelSpaceServer, {:channel, channel_name}}
    )
  end

  @spec start_direct_message_child(String.t(), [String.t()]) :: DynamicSupervisor.on_start_child()
  @spec start_direct_message_child(GenServer.server(), String.t(), [String.t()]) ::
          DynamicSupervisor.on_start_child()
  def start_direct_message_child(supervisor \\ __MODULE__, space_id, participants) do
    DynamicSupervisor.start_child(
      supervisor,
      {RetroHexChat.VirtualSpace.ChannelSpaceServer, {:direct_message, space_id, participants}}
    )
  end

  @doc """
  Start a Construct's runtime. `parent` names the space whose membership it
  borrows; `layout` is what was built in it, read from storage by the caller.
  """
  @spec start_construct_child(
          String.t(),
          {:channel, String.t()} | {:direct_message, String.t(), [String.t()]},
          RetroHexChat.VirtualSpace.ChannelSpaceServer.construct_layout()
        ) :: DynamicSupervisor.on_start_child()
  @spec start_construct_child(
          GenServer.server(),
          String.t(),
          {:channel, String.t()} | {:direct_message, String.t(), [String.t()]},
          RetroHexChat.VirtualSpace.ChannelSpaceServer.construct_layout()
        ) :: DynamicSupervisor.on_start_child()
  def start_construct_child(supervisor \\ __MODULE__, construct_id, parent, layout) do
    DynamicSupervisor.start_child(
      supervisor,
      {RetroHexChat.VirtualSpace.ChannelSpaceServer, {:construct, construct_id, parent, layout}}
    )
  end

  @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def stop_child(supervisor \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end
end
