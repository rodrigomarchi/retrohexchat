defmodule RetroHexChat.VirtualSpace.Registry do
  @moduledoc """
  Registry helpers for virtual space session process lookup.
  Uses Elixir Registry with the via_tuple pattern.
  """

  @registry RetroHexChat.VirtualSpace.SessionRegistry

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  def via_tuple(token) do
    {:via, Registry, {@registry, token}}
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(token) do
    case Registry.lookup(@registry, token) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @spec registry_name() :: atom()
  def registry_name, do: @registry
end
