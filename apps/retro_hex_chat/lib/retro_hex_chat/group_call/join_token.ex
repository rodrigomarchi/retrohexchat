defmodule RetroHexChat.GroupCall.JoinToken do
  @moduledoc """
  Short-lived signed token for raw Phoenix Channel group-call signaling.

  The token binds a registered nickname to one persisted room token and channel
  name. The channel verifies it before allowing SDP/ICE signaling.
  """

  use RetroHexChat.SignedToken, salt: "group_call_join"

  @spec sign(String.t(), String.t(), integer(), String.t()) :: String.t()
  def sign(room_token, channel_name, user_id, nickname) do
    data = %{
      room_token: room_token,
      channel_name: channel_name,
      user_id: user_id,
      nickname: nickname
    }

    sign_data(data)
  end
end
