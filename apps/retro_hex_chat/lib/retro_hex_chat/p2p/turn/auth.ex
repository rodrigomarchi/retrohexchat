defmodule RetroHexChat.P2P.Turn.Auth do
  @moduledoc false
  require Logger

  alias ExSTUN.Message
  alias ExSTUN.Message.Attribute.{MessageIntegrity, Nonce, Realm, Username}
  alias RetroHexChat.P2P.Turn.Config

  @spec authenticate(Message.t(), keyword()) :: {:ok, binary()} | {:error, atom()}
  def authenticate(%Message{} = msg, opts \\ []) do
    config = Keyword.get_lazy(opts, :config, &Config.from_application_env/0)

    with :ok <- verify_message_integrity(msg),
         {:ok, username, nonce, realm} <- verify_attrs_presence(msg),
         :ok <- verify_username(msg.type.method, username, opts),
         :ok <- verify_nonce(nonce, config) do
      password = :crypto.mac(:hmac, :sha, config.auth_secret, username) |> :base64.encode()
      key = Message.lt_key(username, password, realm)

      case Message.authenticate(msg, key) do
        :ok -> {:ok, key}
        {:error, _reason} = err -> err
      end
    else
      {:error, _reason} = err -> err
    end
  end

  @spec generate_credentials(String.t(), Config.t()) :: %{
          username: String.t(),
          password: String.t(),
          ttl: non_neg_integer()
        }
  def generate_credentials(user_id, %Config{} = config) do
    timestamp = System.os_time(:second) + config.credentials_lifetime
    username = "#{timestamp}:#{user_id}"
    password = :crypto.mac(:hmac, :sha, config.auth_secret, username) |> :base64.encode()

    %{username: username, password: password, ttl: config.credentials_lifetime}
  end

  defp verify_message_integrity(msg) do
    case Message.get_attribute(msg, MessageIntegrity) do
      {:ok, %MessageIntegrity{}} -> :ok
      nil -> {:error, :no_message_integrity}
    end
  end

  defp verify_attrs_presence(msg) do
    with {:ok, %Username{value: username}} <- Message.get_attribute(msg, Username),
         {:ok, %Realm{value: realm}} <- Message.get_attribute(msg, Realm),
         {:ok, %Nonce{value: nonce}} <- Message.get_attribute(msg, Nonce) do
      {:ok, username, nonce, realm}
    else
      nil -> {:error, :auth_attrs_missing}
    end
  end

  defp verify_username(:allocate, username, _opts) do
    with [expiry_time | _rest] <- String.split(username, ":", parts: 2),
         {expiry_time, _rem} <- Integer.parse(expiry_time, 10),
         false <- expiry_time - System.os_time(:second) <= 0 do
      :ok
    else
      _other -> {:error, :invalid_username_timestamp}
    end
  end

  defp verify_username(_method, username, opts) do
    valid_username = Keyword.fetch!(opts, :username)
    if username != valid_username, do: {:error, :invalid_username}, else: :ok
  end

  defp verify_nonce(nonce, config) do
    [timestamp, hash] =
      nonce
      |> :base64.decode()
      |> String.split(" ", parts: 2)

    is_hash_valid? = hash == :crypto.hash(:sha256, "#{timestamp}:#{config.nonce_secret}")

    is_stale? =
      String.to_integer(timestamp) + config.nonce_lifetime < System.monotonic_time(:nanosecond)

    if is_hash_valid? and not is_stale?, do: :ok, else: {:error, :stale_nonce}
  end
end
