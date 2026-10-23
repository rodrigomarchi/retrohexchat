defmodule RetroHexChat.Lobby.Registry do
  @moduledoc """
  Registry helpers for P2P lobby session process lookup.
  Uses Elixir Registry with the via_tuple pattern.
  """

  use RetroHexChat.ProcessRegistry,
    registry: RetroHexChat.Lobby.SessionRegistry,
    key: String.t()
end
