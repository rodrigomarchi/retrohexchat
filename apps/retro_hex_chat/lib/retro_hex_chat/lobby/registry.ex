defmodule RetroHexChat.Lobby.Registry do
  @moduledoc """
  Registry helpers for P2P lobby session process lookup.
  Uses Elixir Registry with the via_tuple pattern.
  """

  alias RetroHexChat.ProcessRegistry

  @registry RetroHexChat.Lobby.SessionRegistry

  @spec via_tuple(String.t()) :: ProcessRegistry.via()
  def via_tuple(token), do: ProcessRegistry.via_tuple(@registry, token)

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(token), do: ProcessRegistry.lookup(@registry, token)

  @spec registry_name() :: atom()
  def registry_name, do: @registry
end
