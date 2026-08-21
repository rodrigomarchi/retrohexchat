defmodule RetroHexChat.Lobby.Supervisor do
  @moduledoc """
  DynamicSupervisor for P2P lobby session GenServer processes.
  One child process per active session (Constitution III).
  """

  # A DynamicSupervisor's default intensity — three restarts in five seconds —
  # is sized to stop one child from crash-looping the scheduler. This pool holds
  # nothing but independent sessions: separate people, separate peer
  # connections. Under any real concurrency three of them failing close together
  # is ordinary, and at the default it took the supervisor down and every other
  # session with it — a whole lobby lost to one bad peer.
  #
  # High enough that unrelated failures never collapse the pool, low enough that
  # a genuine crash loop (orders of magnitude faster than this) still trips it.
  @max_restarts 100
  @max_seconds 5

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    DynamicSupervisor.start_link(
      strategy: :one_for_one,
      name: name,
      max_restarts: @max_restarts,
      max_seconds: @max_seconds
    )
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
  def start_child(supervisor \\ __MODULE__, token) do
    DynamicSupervisor.start_child(supervisor, {RetroHexChat.Lobby.SessionServer, token})
  end

  @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def stop_child(supervisor \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end
end
