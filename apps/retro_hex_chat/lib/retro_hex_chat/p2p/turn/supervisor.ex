defmodule RetroHexChat.P2P.Turn.Supervisor do
  @moduledoc """
  Top-level supervisor for the embedded TURN server.
  Starts the AllocationRegistry, AllocationSupervisor, and ListenerSupervisor.
  """
  use Supervisor

  alias RetroHexChat.P2P.Turn.{Config, ListenerSupervisor}

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    config = Config.from_application_env()

    children = [
      {Registry, keys: :unique, name: RetroHexChat.P2P.Turn.AllocationRegistry},
      {DynamicSupervisor,
       name: RetroHexChat.P2P.Turn.AllocationSupervisor, strategy: :one_for_one},
      {ListenerSupervisor, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
