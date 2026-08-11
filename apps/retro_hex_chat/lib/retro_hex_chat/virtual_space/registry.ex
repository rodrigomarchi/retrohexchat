defmodule RetroHexChat.VirtualSpace.Registry do
  @moduledoc """
  Registry helpers for virtual space runtime process lookup.
  Uses Elixir Registry with the via_tuple pattern.
  """

  alias RetroHexChat.ProcessRegistry

  @registry RetroHexChat.VirtualSpace.SessionRegistry

  @type key :: {:channel_space, String.t()} | {:direct_message_space, String.t()}

  @spec via_tuple(key()) :: ProcessRegistry.via()
  def via_tuple(key), do: ProcessRegistry.via_tuple(@registry, key)

  @spec lookup(key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(key), do: ProcessRegistry.lookup(@registry, key)

  @spec registry_name() :: atom()
  def registry_name, do: @registry
end
