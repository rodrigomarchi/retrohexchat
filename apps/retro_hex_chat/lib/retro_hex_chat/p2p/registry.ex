defmodule RetroHexChat.P2P.Registry do
  @moduledoc """
  Registry helpers for P2P session process lookup.
  Uses Elixir Registry with via_tuple pattern.
  """

  @registry RetroHexChat.P2P.SessionRegistry

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
