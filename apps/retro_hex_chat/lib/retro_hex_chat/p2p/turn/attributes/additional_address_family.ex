defmodule RetroHexChat.P2P.Turn.Attributes.AdditionalAddressFamily do
  @moduledoc false
  use RetroHexChat.P2P.Turn.Attributes.ByteEnum,
    type: 0x8000,
    field: :family,
    values: [{0x01, :ipv4}, {0x02, :ipv6}],
    error: :invalid_additional_address_family
end
