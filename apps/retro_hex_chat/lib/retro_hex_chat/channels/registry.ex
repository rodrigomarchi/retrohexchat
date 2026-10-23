defmodule RetroHexChat.Channels.Registry do
  @moduledoc """
  Registry helpers for channel process lookup.
  Uses Elixir Registry with via_tuple pattern.
  """

  use RetroHexChat.ProcessRegistry,
    registry: RetroHexChat.Channels.ChannelRegistry,
    key: String.t()
end
