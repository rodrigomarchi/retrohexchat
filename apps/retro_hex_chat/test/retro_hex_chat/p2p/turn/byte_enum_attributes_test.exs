defmodule RetroHexChat.P2P.Turn.ByteEnumAttributesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias ExSTUN.Message.RawAttribute

  alias RetroHexChat.P2P.Turn.Attributes.{
    AdditionalAddressFamily,
    RequestedAddressFamily,
    RequestedTransport
  }

  defp decode(module, value),
    do: module.from_raw(%RawAttribute{type: module.type(), value: value}, nil)

  test "REQUESTED-TRANSPORT reads UDP and TCP, and nothing else" do
    assert RequestedTransport.type() == 0x0019

    assert decode(RequestedTransport, <<17, 0, 0, 0>>) ==
             {:ok, %RequestedTransport{protocol: :udp}}

    assert decode(RequestedTransport, <<6, 0, 0, 0>>) ==
             {:ok, %RequestedTransport{protocol: :tcp}}

    assert decode(RequestedTransport, <<17, 1, 0, 0>>) == {:error, :invalid_requested_transport}
  end

  test "the two address-family attributes read IPv4 and IPv6 under their own types" do
    assert RequestedAddressFamily.type() == 0x0017
    assert AdditionalAddressFamily.type() == 0x8000

    assert decode(RequestedAddressFamily, <<1, 0, 0, 0>>) ==
             {:ok, %RequestedAddressFamily{family: :ipv4}}

    assert decode(AdditionalAddressFamily, <<2, 0, 0, 0>>) ==
             {:ok, %AdditionalAddressFamily{family: :ipv6}}

    assert decode(RequestedAddressFamily, <<3, 0, 0, 0>>) ==
             {:error, :invalid_requested_address_family}
  end
end
