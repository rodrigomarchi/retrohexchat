defmodule RetroHexChat.Channels.Registry do
  @moduledoc """
  Registry helpers for channel process lookup.
  Uses Elixir Registry with via_tuple pattern.
  """

  alias RetroHexChat.ProcessRegistry

  @registry RetroHexChat.Channels.ChannelRegistry

  @spec via_tuple(String.t()) :: ProcessRegistry.via()
  def via_tuple(channel_name), do: ProcessRegistry.via_tuple(@registry, channel_name)

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(channel_name), do: ProcessRegistry.lookup(@registry, channel_name)

  @spec registry_name() :: atom()
  def registry_name, do: @registry
end
