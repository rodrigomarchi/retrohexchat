defmodule RetroHexChat.GroupCall.Supervisor do
  @moduledoc """
  Supervision tree for embedded group-call SFU runtime processes.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      RetroHexChat.GroupCall.RoomSupervisor,
      RetroHexChat.GroupCall.PeerSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
