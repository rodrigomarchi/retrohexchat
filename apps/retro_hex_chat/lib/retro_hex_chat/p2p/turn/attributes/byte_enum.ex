defmodule RetroHexChat.P2P.Turn.Attributes.ByteEnum do
  @moduledoc """
  A TURN attribute whose value is one byte from a fixed table followed by
  three reserved zero bytes (RFC 8656 REQUESTED-TRANSPORT,
  REQUESTED-ADDRESS-FAMILY, ADDITIONAL-ADDRESS-FAMILY). The attribute declares
  its type, the struct field the byte decodes into, the table and the error
  for anything else; decoding is the same for all of them.

      use RetroHexChat.P2P.Turn.Attributes.ByteEnum,
        type: 0x0019,
        field: :protocol,
        values: [{17, :udp}, {6, :tcp}],
        error: :invalid_requested_transport
  """

  @doc false
  defmacro __using__(opts) do
    type = Keyword.fetch!(opts, :type)
    field = Keyword.fetch!(opts, :field)
    values = Keyword.fetch!(opts, :values)
    error = Keyword.fetch!(opts, :error)

    quote bind_quoted: [type: type, field: field, values: values, error: error] do
      @behaviour ExSTUN.Message.Attribute

      @attr_type type
      @enforce_keys [field]
      defstruct @enforce_keys

      @type t() :: %__MODULE__{}

      @impl true
      def type, do: @attr_type

      @impl true
      def from_raw(%ExSTUN.Message.RawAttribute{value: value}, _message), do: decode(value)

      for {byte, value} <- values do
        defp decode(<<unquote(byte), 0, 0, 0>>),
          do: {:ok, struct(__MODULE__, [{unquote(field), unquote(value)}])}
      end

      defp decode(_other), do: {:error, unquote(error)}
    end
  end
end
