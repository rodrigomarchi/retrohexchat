defmodule RetroHexChat.P2P do
  @moduledoc """
  Shared WebRTC infrastructure for P2P sessions: signal validation, ICE/TURN
  server configuration and the rate limiters (`RateLimiter`,
  `SignalingRateLimit`). The session lifecycle itself lives in
  `RetroHexChat.Lobby`; the legacy `p2p_sessions` table is retained
  read-only for the admin tooling (`Schema.Session`).
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.P2P.Turn.{Auth, Config}

  @spec turn_configured?() :: boolean()
  def turn_configured? do
    listener_count = Application.get_env(:retro_hex_chat, :turn_listener_count, 0)
    listener_count > 0
  end

  @valid_signal_types ~w(offer answer ice-candidate)

  @spec validate_signal(map()) :: {:ok, map()} | {:error, :invalid_signal}
  def validate_signal(%{"type" => type} = signal) when type in @valid_signal_types do
    case type do
      t when t in ["offer", "answer"] ->
        sdp = Map.get(signal, "sdp")

        if is_binary(sdp) and sdp != "" do
          {:ok, %{type: type, sdp: sdp}}
        else
          {:error, :invalid_signal}
        end

      "ice-candidate" ->
        candidate = Map.get(signal, "candidate")

        if is_map(candidate) do
          {:ok, %{type: type, candidate: candidate}}
        else
          {:error, :invalid_signal}
        end
    end
  end

  def validate_signal(_), do: {:error, :invalid_signal}

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
            dgettext("p2p", "turn:%{relay_ip}:%{listen_port}?transport=udp",
              relay_ip: relay_ip,
              listen_port: listen_port
            )
          ],
          username: creds.username,
          credential: creds.password
        }
      ]
    else
      [%{urls: [dgettext("p2p", "stun:stun.l.google.com:19302")]}]
    end
  end
end
