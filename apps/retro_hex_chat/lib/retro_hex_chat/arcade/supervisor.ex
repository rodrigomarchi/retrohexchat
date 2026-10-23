defmodule RetroHexChat.Arcade.Supervisor do
  @moduledoc """
  DynamicSupervisor for solo arcade session GenServer processes.
  One child process per active arcade session (Constitution III).
  """

  use RetroHexChat.ProcessSupervisor, child: RetroHexChat.Arcade.SoloSessionServer
end
