defmodule RetroHexChat.Chat.PasswordEncryption do
  @moduledoc """
  Reversible AES-GCM encryption for channel passwords stored in favorites.
  Uses Plug.Crypto.MessageEncryptor with keys derived from secret_key_base.
  """

  alias Plug.Crypto.{KeyGenerator, MessageEncryptor}

  @encrypt_salt "favorites_password_encryption"
  @sign_salt "favorites_password_signing"
  @key_length 32

  @spec encrypt(String.t()) :: String.t()
  def encrypt(plain_text) when is_binary(plain_text) and plain_text != "" do
    {secret, sign_secret} = derive_keys()
    MessageEncryptor.encrypt(plain_text, secret, sign_secret)
  end

  @spec decrypt(String.t()) :: {:ok, String.t()} | :error
  def decrypt(encrypted) when is_binary(encrypted) and encrypted != "" do
    {secret, sign_secret} = derive_keys()

    case MessageEncryptor.decrypt(encrypted, secret, sign_secret) do
      {:ok, plain} -> {:ok, plain}
      :error -> :error
    end
  end

  def decrypt(nil), do: {:ok, nil}
  def decrypt(""), do: {:ok, nil}

  @spec derive_keys() :: {binary(), binary()}
  defp derive_keys do
    secret_key_base =
      Application.get_env(:retro_hex_chat_web, RetroHexChatWeb.Endpoint)[:secret_key_base]

    secret = KeyGenerator.generate(secret_key_base, @encrypt_salt, length: @key_length)
    sign_secret = KeyGenerator.generate(secret_key_base, @sign_salt, length: @key_length)

    {secret, sign_secret}
  end
end
