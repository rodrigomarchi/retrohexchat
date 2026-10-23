defmodule RetroHexChat.GroupCall.RoomSupervisor do
  @moduledoc """
  DynamicSupervisor for active group-call rooms.
  """

  use RetroHexChat.ProcessSupervisor, child: RetroHexChat.GroupCall.RoomServer
end
