defmodule RetroHexChat.P2P do
  @moduledoc """
  Shared WebRTC infrastructure for P2P sessions: signal validation, ICE/TURN
  server configuration and the rate limiters (`RateLimiter`,
  `SignalingRateLimit`). The session lifecycle itself lives in
  `RetroHexChat.Lobby`.
  """
  alias RetroHexChat.Calls.SignalValidation
  alias RetroHexChat.P2P.Turn.{Auth, Config}

  @spec turn_configured?() :: boolean()
  def turn_configured? do
    listener_count = Application.get_env(:retro_hex_chat, :turn_listener_count, 0)
    listener_count > 0
  end

  @valid_signal_types ~w(offer answer ice-candidate)

  @spec validate_signal(map()) :: {:ok, map()} | {:error, :invalid_signal}
  def validate_signal(%{"type" => type} = signal) when type in @valid_signal_types do
    metadata = signal_metadata(signal)

    case type do
      t when t in ["offer", "answer"] ->
        with {:ok, sdp} <- SignalValidation.validate_sdp(Map.get(signal, "sdp")) do
          {:ok, Map.merge(%{type: type, sdp: sdp}, metadata)}
        end

      "ice-candidate" ->
        with {:ok, candidate} <-
               SignalValidation.validate_candidate(Map.get(signal, "candidate")) do
          {:ok, Map.merge(%{type: type, candidate: candidate}, Map.take(metadata, [:epoch]))}
        end
    end
  end

  def validate_signal(_), do: {:error, :invalid_signal}

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

  # An unusable offer id is dropped rather than refusing the signal: it only
  # correlates an answer with the offer that prompted it, so losing it degrades
  # recovery instead of breaking the call. The group-call channel refuses.
  defp maybe_put_offer_id(metadata, offer_id) do
    case SignalValidation.validate_offer_id(offer_id) do
      {:ok, nil} -> metadata
      {:ok, valid} -> Map.put(metadata, :offer_id, valid)
      {:error, :invalid_signal} -> metadata
    end
  end

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
