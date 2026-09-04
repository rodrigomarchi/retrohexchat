defmodule RetroHexChat.GroupCall.JoinToken do
  @moduledoc """
  Short-lived signed token for raw Phoenix Channel group-call signaling.

  The token binds a registered nickname to one persisted room token and channel
  name. The channel verifies it before allowing SDP/ICE signaling.
  """

  alias RetroHexChat.SignedToken

  @salt "group_call_join"

  @spec sign(String.t(), String.t(), integer(), String.t()) :: String.t()
  def sign(room_token, channel_name, user_id, nickname) do
    data = %{
      room_token: room_token,
      channel_name: channel_name,
      user_id: user_id,
      nickname: nickname
    }

    SignedToken.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t(), keyword()) :: {:ok, map()} | {:error, :expired | :invalid}
  def verify(token, opts \\ []),
    do: SignedToken.verify(secret_key_base(), @salt, token, opts)

  @spec max_age() :: pos_integer()
  def max_age, do: SignedToken.default_max_age()

  defp secret_key_base do
    Application.get_env(:retro_hex_chat, :channel_space_join_secret) ||
      raise "Missing :channel_space_join_secret configuration"
  end
end
