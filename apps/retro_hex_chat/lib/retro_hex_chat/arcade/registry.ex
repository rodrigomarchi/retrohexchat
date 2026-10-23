defmodule RetroHexChat.Arcade.Registry do
  @moduledoc """
  Registry helpers for solo arcade session process lookup.
  Uses Elixir Registry with via_tuple pattern.
  """

  use RetroHexChat.ProcessRegistry,
    registry: RetroHexChat.Arcade.SessionRegistry,
    key: String.t()
end
