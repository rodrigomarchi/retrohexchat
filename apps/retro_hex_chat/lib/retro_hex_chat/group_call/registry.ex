defmodule RetroHexChat.GroupCall.Registry do
  @moduledoc """
  Registry helpers for group-call room and peer runtime processes.
  """

  alias RetroHexChat.ProcessRegistry

  @room_registry RetroHexChat.GroupCall.RoomRegistry
  @peer_registry RetroHexChat.GroupCall.PeerRegistry

  @type room_key :: {:room, String.t()} | {:channel, String.t()}
  @type peer_key :: {:peer, integer(), integer()}

  @spec room_via_tuple(room_key()) :: ProcessRegistry.via()
  def room_via_tuple(key), do: ProcessRegistry.via_tuple(@room_registry, key)

  @spec peer_via_tuple(peer_key()) :: ProcessRegistry.via()
  def peer_via_tuple(key), do: ProcessRegistry.via_tuple(@peer_registry, key)

  @spec lookup_room(room_key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_room(key), do: ProcessRegistry.lookup(@room_registry, key)

  @spec lookup_peer(peer_key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_peer(key), do: ProcessRegistry.lookup(@peer_registry, key)

  @spec room_registry_name() :: atom()
  def room_registry_name, do: @room_registry

  @spec peer_registry_name() :: atom()
  def peer_registry_name, do: @peer_registry
end
