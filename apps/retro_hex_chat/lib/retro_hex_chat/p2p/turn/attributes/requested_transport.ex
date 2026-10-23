defmodule RetroHexChat.P2P.Turn.Attributes.RequestedTransport do
  @moduledoc false
  use RetroHexChat.P2P.Turn.Attributes.ByteEnum,
    type: 0x0019,
    field: :protocol,
    values: [{17, :udp}, {6, :tcp}],
    error: :invalid_requested_transport
end
