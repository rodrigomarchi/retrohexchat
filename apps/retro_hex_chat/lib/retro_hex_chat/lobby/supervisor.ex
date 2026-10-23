defmodule RetroHexChat.Lobby.Supervisor do
  @moduledoc """
  DynamicSupervisor for P2P lobby session GenServer processes.
  One child process per active session (Constitution III).
  """

  use RetroHexChat.ProcessSupervisor,
    child: RetroHexChat.Lobby.SessionServer,
    options: [max_restarts: 50, max_seconds: 5]
end
