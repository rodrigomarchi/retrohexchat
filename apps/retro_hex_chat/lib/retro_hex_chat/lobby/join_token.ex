defmodule RetroHexChat.Lobby.JoinToken do
  @moduledoc """
  Signed token that authorizes a raw Phoenix Channel join for P2P signaling.

  The token binds a browser to one persisted session token and one user. It is
  the same shape as `RetroHexChat.GroupCall.JoinToken` and deliberately carries
  a **different salt**: a salt is what stops a token minted for a space or a
  conference from being spent on a P2P door, and that is the whole reason
  `SignedToken` takes one.

  It is an identity binding and never an authorization. Whether this user may
  signal in this session is `Lobby.Policy.can_join?/2`, and the channel asks it
  on every join — which is why the token may outlive an hour: the session's own
  lifecycle is what decides when signaling stops, and a call that runs past a
  socket reconnect must be able to rejoin its own channel.
  """

  alias RetroHexChat.SignedToken

  @salt "p2p_join"

  # Long enough that a call outliving a socket reconnect can rejoin its own
  # channel, short enough that a token copied out of a page stops working the
  # same day. The policy check on every join is what actually guards the room.
  @max_age 12 * 60 * 60

  @spec sign(String.t(), integer(), String.t()) :: String.t()
  def sign(session_token, user_id, nickname) do
    data = %{session_token: session_token, user_id: user_id, nickname: nickname}

    SignedToken.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t(), keyword()) :: {:ok, map()} | {:error, :expired | :invalid}
  def verify(token, opts \\ []) do
    SignedToken.verify(secret_key_base(), @salt, token, Keyword.put_new(opts, :max_age, @max_age))
  end

  @spec max_age() :: pos_integer()
  def max_age, do: @max_age

  defp secret_key_base do
    Application.get_env(:retro_hex_chat, :group_call_join_secret) ||
      Application.get_env(:retro_hex_chat, :channel_space_join_secret) ||
      raise "Missing :group_call_join_secret or :channel_space_join_secret configuration"
  end
end
