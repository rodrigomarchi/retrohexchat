defmodule RetroHexChat.Bots.Supervisor do
  @moduledoc """
  DynamicSupervisor for bot processes.
  """
  use DynamicSupervisor

  alias RetroHexChat.Bots.Server

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_bot(map()) :: DynamicSupervisor.on_start_child()
  def start_bot(bot_data) do
    DynamicSupervisor.start_child(__MODULE__, {Server, bot_data})
  end

  @spec stop_bot(String.t()) :: :ok | {:error, :not_found}
  def stop_bot(bot_nickname) do
    case RetroHexChat.Bots.Registry.lookup(bot_nickname) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
