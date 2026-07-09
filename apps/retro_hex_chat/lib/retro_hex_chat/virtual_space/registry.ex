defmodule RetroHexChat.VirtualSpace.Registry do
  @moduledoc """
  Registry helpers for virtual space runtime process lookup.
  Uses Elixir Registry with the via_tuple pattern.
  """

  @registry RetroHexChat.VirtualSpace.SessionRegistry

  @type key :: {:channel_space, String.t()} | {:direct_message_space, String.t()}

  @spec via_tuple(key()) :: {:via, Registry, {atom(), key()}}
  def via_tuple(key) do
    {:via, Registry, {@registry, key}}
  end

  @spec lookup(key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(key) do
    case Registry.lookup(@registry, key) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @spec registry_name() :: atom()
  def registry_name, do: @registry
end
