defmodule RetroHexChat.P2P do
  @moduledoc """
  Public API for the P2P bounded context.
  All external callers use this module.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.P2P.{Queries, Service, SessionServer}
  alias RetroHexChat.P2P.Schema.Session
  alias RetroHexChat.P2P.Turn.{Auth, Config}

  @spec create_session(integer(), integer(), keyword()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id, peer_id, opts \\ []), to: Service

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate join_session(token, user_id), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec close_sessions_between(integer(), integer()) :: :ok
  defdelegate close_sessions_between(user_a_id, user_b_id), to: Service

  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @spec transition_status(String.t(), atom()) :: :ok | {:error, String.t()}
  defdelegate transition_status(token, new_status), to: SessionServer, as: :transition

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate send_lobby_message(token, user_id, content), to: Service

  @spec request_action(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate request_action(token, user_id, action_type), to: Service

  @spec respond_action(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  defdelegate respond_action(token, user_id, accepted?), to: Service

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
