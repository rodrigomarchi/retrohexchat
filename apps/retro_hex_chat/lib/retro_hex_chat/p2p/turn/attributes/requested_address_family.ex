defmodule RetroHexChat.P2P.Turn.Attributes.RequestedAddressFamily do
  @moduledoc false
  use RetroHexChat.P2P.Turn.Attributes.ByteEnum,
    type: 0x0017,
    field: :family,
    values: [{0x01, :ipv4}, {0x02, :ipv6}],
    error: :invalid_requested_address_family
end
