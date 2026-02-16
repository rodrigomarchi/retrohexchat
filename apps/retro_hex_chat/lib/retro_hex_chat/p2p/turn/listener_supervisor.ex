defmodule RetroHexChat.P2P.Turn.ListenerSupervisor do
  @moduledoc false
  use Supervisor

  alias RetroHexChat.P2P.Turn.{Config, Listener}

  @spec start_link(Config.t()) :: Supervisor.on_start()
  def start_link(%Config{} = config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(%Config{} = config) do
    children =
      if config.listener_count > 0 do
        for id <- 1..config.listener_count do
          Supervisor.child_spec(
            {Listener, [config.listen_ip, config.listen_port, id, config]},
            id: "turn_listener_#{id}"
          )
        end
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
