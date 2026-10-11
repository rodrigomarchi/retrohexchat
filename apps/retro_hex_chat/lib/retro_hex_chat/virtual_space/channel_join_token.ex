defmodule RetroHexChat.VirtualSpace.ChannelJoinToken do
  @moduledoc """
  Short-lived signed token that authorizes a Phoenix Channel join to a
  channel-backed virtual space.

  The token binds a nickname to a concrete channel name. `SpaceChannel` verifies
  it before touching the channel-space runtime, so the channel never trusts raw
  client input for identity.
  """

  @salt "channel_space_join"

  alias RetroHexChat.SignedToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace

  @spec sign(String.t(), integer() | nil, String.t()) :: String.t()
  def sign(channel_name, user_id, nickname) do
    data = %{
      space_kind: "channel",
      channel_name: channel_name,
      user_id: user_id,
      nickname: nickname
    }

    SignedToken.sign(secret_key_base(), @salt, data)
  end

  @spec sign_direct_message(String.t(), integer() | nil, String.t(), [String.t()]) :: String.t()
  def sign_direct_message(space_id, user_id, nickname, participants) do
    {:ok, participants} = DirectMessageSpace.normalize_participants(participants)

    data = %{
      space_kind: "direct_message",
      space_id: space_id,
      user_id: user_id,
      nickname: nickname,
      participants: participants
    }

    SignedToken.sign(secret_key_base(), @salt, data)
  end

  @doc """
  The token for a space's Construct. It names the Construct and, for a private
  space's, the pair it belongs to — the same two names the private space's own
  token carries, because the Construct admits exactly the same two people.
  """
  @spec sign_construct(String.t(), integer() | nil, String.t(), [String.t()] | nil) ::
          String.t()
  def sign_construct(construct_id, user_id, nickname, participants) do
    data = %{
      space_kind: "construct",
      space_id: construct_id,
      user_id: user_id,
      nickname: nickname,
      participants: participants
    }

    SignedToken.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :expired | :invalid}
  def verify(token, opts \\ []),
    do: SignedToken.verify(secret_key_base(), @salt, token, opts)

  @spec max_age() :: pos_integer()
  def max_age, do: SignedToken.default_max_age()

  defp secret_key_base do
    Application.get_env(:retro_hex_chat, :channel_space_join_secret) ||
      raise "Missing :channel_space_join_secret configuration"
  end
end
