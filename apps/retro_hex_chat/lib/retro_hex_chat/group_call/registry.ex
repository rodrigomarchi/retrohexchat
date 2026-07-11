defmodule RetroHexChat.GroupCall.Registry do
  @moduledoc """
  Registry helpers for group-call room and peer runtime processes.
  """

  @room_registry RetroHexChat.GroupCall.RoomRegistry
  @peer_registry RetroHexChat.GroupCall.PeerRegistry

  @type room_key :: {:room, String.t()} | {:channel, String.t()}
  @type peer_key :: {:peer, integer(), integer()}

  @spec room_via_tuple(room_key()) :: {:via, Registry, {atom(), room_key()}}
  def room_via_tuple(key), do: {:via, Registry, {@room_registry, key}}

  @spec peer_via_tuple(peer_key()) :: {:via, Registry, {atom(), peer_key()}}
  def peer_via_tuple(key), do: {:via, Registry, {@peer_registry, key}}

  @spec lookup_room(room_key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_room(key), do: lookup(@room_registry, key)

  @spec lookup_peer(peer_key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_peer(key), do: lookup(@peer_registry, key)

  @spec room_registry_name() :: atom()
  def room_registry_name, do: @room_registry

  @spec peer_registry_name() :: atom()
  def peer_registry_name, do: @peer_registry

  defp lookup(registry, key) do
    case Registry.lookup(registry, key) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
end
