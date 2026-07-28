defmodule RetroHexChat.P2P do
  @moduledoc """
  Shared WebRTC infrastructure for P2P sessions: signal validation, ICE/TURN
  server configuration and the rate limiters (`RateLimiter`,
  `SignalingRateLimit`). The session lifecycle itself lives in
  `RetroHexChat.Lobby`.
  """
  alias RetroHexChat.P2P.Turn.{Auth, Config}

  @spec turn_configured?() :: boolean()
  def turn_configured? do
    listener_count = Application.get_env(:retro_hex_chat, :turn_listener_count, 0)
    listener_count > 0
  end

  @valid_signal_types ~w(offer answer ice-candidate)
  @max_sdp_bytes 256_000
  @max_candidate_bytes 4_096
  @max_mid_bytes 64
  @max_offer_id_bytes 80

  @spec validate_signal(map()) :: {:ok, map()} | {:error, :invalid_signal}
  def validate_signal(%{"type" => type} = signal) when type in @valid_signal_types do
    metadata = signal_metadata(signal)

    case type do
      t when t in ["offer", "answer"] ->
        sdp = Map.get(signal, "sdp")

        if valid_sdp?(sdp) do
          {:ok, Map.merge(%{type: type, sdp: sdp}, metadata)}
        else
          {:error, :invalid_signal}
        end

      "ice-candidate" ->
        candidate = Map.get(signal, "candidate")

        with {:ok, candidate} <- validate_candidate(candidate) do
          {:ok, Map.merge(%{type: type, candidate: candidate}, Map.take(metadata, [:epoch]))}
        end
    end
  end

  def validate_signal(_), do: {:error, :invalid_signal}

  defp valid_sdp?(sdp) do
    is_binary(sdp) and sdp != "" and byte_size(sdp) <= @max_sdp_bytes
  end

  defp validate_candidate(%{} = candidate) do
    candidate_text = Map.get(candidate, "candidate")
    sdp_mid = Map.get(candidate, "sdpMid")
    sdp_m_line_index = Map.get(candidate, "sdpMLineIndex")

    cond do
      not (is_binary(candidate_text) and candidate_text != "" and
               byte_size(candidate_text) <= @max_candidate_bytes) ->
        {:error, :invalid_signal}

      not valid_mid?(sdp_mid) ->
        {:error, :invalid_signal}

      not valid_m_line_index?(sdp_m_line_index) ->
        {:error, :invalid_signal}

      is_nil(sdp_mid) and is_nil(sdp_m_line_index) ->
        {:error, :invalid_signal}

      true ->
        {:ok,
         %{"candidate" => candidate_text}
         |> maybe_put_candidate_value("sdpMid", sdp_mid)
         |> maybe_put_candidate_value("sdpMLineIndex", sdp_m_line_index)}
    end
  end

  defp validate_candidate(_), do: {:error, :invalid_signal}

  defp valid_mid?(nil), do: true
  defp valid_mid?(mid), do: is_binary(mid) and byte_size(mid) <= @max_mid_bytes

  defp valid_m_line_index?(nil), do: true
  defp valid_m_line_index?(index), do: is_integer(index) and index >= 0 and index < 128

  defp maybe_put_candidate_value(candidate, _key, nil), do: candidate
  defp maybe_put_candidate_value(candidate, key, value), do: Map.put(candidate, key, value)

  defp signal_metadata(signal) do
    %{}
    |> maybe_put_epoch(Map.get(signal, "epoch"))
    |> maybe_put_offer_id(Map.get(signal, "offer_id"))
    |> maybe_put_boolean(:recover, Map.get(signal, "recover"))
    |> maybe_put_boolean(:connection_reset, Map.get(signal, "connection_reset"))
  end

  defp maybe_put_epoch(metadata, epoch)
       when is_integer(epoch) and epoch > 0 and epoch < 1_000_000 do
    Map.put(metadata, :epoch, epoch)
  end

  defp maybe_put_epoch(metadata, _epoch), do: metadata

  defp maybe_put_offer_id(metadata, offer_id)
       when is_binary(offer_id) and offer_id != "" and byte_size(offer_id) <= @max_offer_id_bytes do
    Map.put(metadata, :offer_id, offer_id)
  end

  defp maybe_put_offer_id(metadata, _offer_id), do: metadata

  defp maybe_put_boolean(metadata, key, value) when is_boolean(value),
    do: Map.put(metadata, key, value)

  defp maybe_put_boolean(metadata, _key, _value), do: metadata

  @spec ice_servers(String.t()) :: [map()]
  def ice_servers(user_id) do
    if turn_configured?() do
      config = Config.from_application_env()
      creds = Auth.generate_credentials(user_id, config)

      listen_port = config.listen_port
      relay_ip = :inet.ntoa(config.relay_ip) |> to_string()

      [
        %{
          urls: [
            "turn:#{relay_ip}:#{listen_port}?transport=udp"
          ],
          username: creds.username,
          credential: creds.password
        }
      ]
    else
      [%{urls: ["stun:stun.l.google.com:19302"]}]
    end
  end
end
