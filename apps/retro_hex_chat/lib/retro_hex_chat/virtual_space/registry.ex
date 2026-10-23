defmodule RetroHexChat.VirtualSpace.Registry do
  @moduledoc """
  Registry helpers for virtual space runtime process lookup.
  Uses Elixir Registry with the via_tuple pattern.
  """

  @type key ::
          {:channel_space, String.t()}
          | {:direct_message_space, String.t()}
          | {:construct_space, String.t()}

  use RetroHexChat.ProcessRegistry,
    registry: RetroHexChat.VirtualSpace.SessionRegistry,
    key: key()
end
