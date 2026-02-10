defmodule RetroHexChat.Channels.Registry do
  @moduledoc """
  Registry helpers for channel process lookup.
  Uses Elixir Registry with via_tuple pattern.
  """

  @registry RetroHexChat.Channels.ChannelRegistry

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  def via_tuple(channel_name) do
    {:via, Registry, {@registry, channel_name}}
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(channel_name) do
    case Registry.lookup(@registry, channel_name) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @spec registry_name() :: atom()
  def registry_name, do: @registry
end
