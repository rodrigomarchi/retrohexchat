defmodule RetroHexChat.P2P.Turn.Utils do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext
  require Logger

  alias ExSTUN.Message
  alias ExSTUN.Message.Attribute.{ErrorCode, Nonce, Realm}
  alias ExSTUN.Message.Method
  alias ExSTUN.Message.Type

  alias RetroHexChat.P2P.Turn.Attributes.Lifetime
  alias RetroHexChat.P2P.Turn.Config

  @spec get_lifetime(Message.t(), Config.t()) :: {:ok, integer()} | {:error, :invalid_lifetime}
  def get_lifetime(msg, %Config{} = config) do
    case Message.get_attribute(msg, Lifetime) do
      {:ok, %Lifetime{lifetime: lifetime}} ->
        desired_lifetime =
          if lifetime == 0,
            do: 0,
            else:
              max(
                config.default_allocation_lifetime,
                min(lifetime, config.max_allocation_lifetime)
              )

        {:ok, desired_lifetime}

      nil ->
        {:ok, config.default_allocation_lifetime}

      {:error, _reason} ->
        {:error, :invalid_lifetime}
    end
  end

  @spec build_error(atom(), integer(), Method.t(), Config.t()) ::
          {response :: binary(), log_msg :: String.t()}
  def build_error(reason, t_id, method, %Config{} = config) do
    {log_msg, code, with_attrs?} = translate_error(reason)
    error_type = %Type{class: :error_response, method: method}

    attrs = [%ErrorCode{code: code}]

    attrs =
      if with_attrs? do
        attrs ++ [%Nonce{value: build_nonce(config)}, %Realm{value: config.realm}]
      else
        attrs
      end

    response =
      t_id
      |> Message.new(error_type, attrs)
      |> Message.encode()

    {response, log_msg <> dgettext("p2p", ", rejected")}
  end

  @spec build_nonce(Config.t()) :: String.t()
  def build_nonce(%Config{} = config) do
    timestamp = System.monotonic_time(:nanosecond)
    hash = :crypto.hash(:sha256, "#{timestamp}:#{config.nonce_secret}")
    "#{timestamp} #{hash}" |> :base64.encode()
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp translate_error(:allocation_not_found),
    do: {dgettext("p2p", "Allocation mismatch: allocation does not exist"), 437, false}

  defp translate_error(:allocation_exists),
    do: {dgettext("p2p", "Allocation mismatch: allocation already exists"), 437, false}

  defp translate_error(:requested_transport_tcp),
    do: {dgettext("p2p", "Unsupported REQUESTED-TRANSPORT: TCP"), 442, false}

  defp translate_error(:invalid_requested_transport),
    do: {dgettext("p2p", "No or malformed REQUESTED-TRANSPORT"), 400, false}

  defp translate_error(:invalid_even_port),
    do: {dgettext("p2p", "Failed to decode EVEN-PORT"), 400, false}

  defp translate_error(:invalid_requested_address_family),
    do: {dgettext("p2p", "Failed to decode REQUESTED-ADDRESS-FAMILY"), 400, false}

  defp translate_error(:reservation_token_with_others),
    do:
      {dgettext("p2p", "RESERVATION-TOKEN and (EVEN-PORT|REQUESTED-FAMILY) in the message"), 400,
       false}

  defp translate_error(:reservation_token_unsupported),
    do: {dgettext("p2p", "RESERVATION-TOKEN unsupported"), 400, false}

  defp translate_error(:invalid_reservation_token),
    do: {dgettext("p2p", "Failed to decode RESERVATION-TOKEN"), 400, false}

  defp translate_error(:requested_address_family_unsupported),
    do: {dgettext("p2p", "REQUESTED-ADDRESS-FAMILY with IPv6 unsupported"), 440, false}

  defp translate_error(:even_port_unsupported),
    do: {dgettext("p2p", "EVEN-PORT unsupported"), 400, false}

  defp translate_error(:out_of_ports),
    do: {dgettext("p2p", "No available ports left"), 508, false}

  defp translate_error(:invalid_lifetime),
    do: {dgettext("p2p", "Failed to decode LIFETIME"), 400, false}

  defp translate_error(:no_matching_message_integrity),
    do: {dgettext("p2p", "Auth failed, invalid MESSAGE-INTEGRITY"), 400, false}

  defp translate_error(:no_message_integrity),
    do: {dgettext("p2p", "No message integrity attribute"), 401, true}

  defp translate_error(:auth_attrs_missing),
    do: {dgettext("p2p", "No username, nonce or realm attribute"), 400, false}

  defp translate_error(:invalid_username_timestamp),
    do: {dgettext("p2p", "Username timestamp expired"), 401, true}

  defp translate_error(:invalid_username),
    do: {dgettext("p2p", "Username differs from the one used previously"), 441, true}

  defp translate_error(:stale_nonce),
    do: {dgettext("p2p", "Stale nonce"), 438, true}

  defp translate_error(:no_xor_peer_address_attribute),
    do: {dgettext("p2p", "No XOR-PEER-ADDRESS attribute"), 400, false}

  defp translate_error(:invalid_xor_peer_address),
    do: {dgettext("p2p", "Failed to decode XOR-PEER-ADDRESS"), 400, false}

  defp translate_error(:no_data_attribute),
    do: {dgettext("p2p", "No DATA attribute"), 400, false}

  defp translate_error(:invalid_data),
    do: {dgettext("p2p", "Failed to decode DATA"), 400, false}

  defp translate_error(:no_channel_number_attribute),
    do: {dgettext("p2p", "No CHANNEL-NUMBER attribute"), 400, false}

  defp translate_error(:invalid_channel_number),
    do: {dgettext("p2p", "Failed to decode CHANNEL-NUMBER"), 400, false}

  defp translate_error(:channel_number_out_of_range),
    do: {dgettext("p2p", "Channel number is out of allowed range"), 400, false}

  defp translate_error(:channel_number_bound),
    do: {dgettext("p2p", "Channel number is already bound"), 400, false}

  defp translate_error(:addr_bound_to_channel),
    do: {dgettext("p2p", "Address is already bound to channel"), 400, false}

  defp translate_error(other) do
    Logger.error("Unsupported error type: #{other}")
    {dgettext("p2p", "Unknown error"), 500, false}
  end
end
