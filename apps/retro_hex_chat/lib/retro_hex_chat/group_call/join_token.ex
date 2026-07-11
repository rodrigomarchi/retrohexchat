defmodule RetroHexChat.GroupCall.JoinToken do
  @moduledoc """
  Short-lived signed token for raw Phoenix Channel group-call signaling.

  The token binds a registered nickname to one persisted room token and channel
  name. The channel verifies it before allowing SDP/ICE signaling.
  """

  @salt "group_call_join"
  @max_age 3_600

  @spec sign(String.t(), String.t(), integer(), String.t()) :: String.t()
  def sign(room_token, channel_name, user_id, nickname) do
    data = %{
      room_token: room_token,
      channel_name: channel_name,
      user_id: user_id,
      nickname: nickname
    }

    Phoenix.Token.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t(), keyword()) :: {:ok, map()} | {:error, :expired | :invalid}
  def verify(token, opts \\ []) do
    max_age = Keyword.get(opts, :max_age, @max_age)

    case Phoenix.Token.verify(secret_key_base(), @salt, token, max_age: max_age) do
      {:ok, data} -> {:ok, data}
      {:error, :expired} -> {:error, :expired}
      {:error, _reason} -> {:error, :invalid}
    end
  end

  @spec max_age() :: pos_integer()
  def max_age, do: @max_age

  defp secret_key_base do
    Application.get_env(:retro_hex_chat, :group_call_join_secret) ||
      Application.get_env(:retro_hex_chat, :channel_space_join_secret) ||
      raise "Missing :group_call_join_secret configuration"
  end
end
