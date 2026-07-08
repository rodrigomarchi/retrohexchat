defmodule RetroHexChat.VirtualSpace.ChannelJoinToken do
  @moduledoc """
  Short-lived signed token that authorizes a Phoenix Channel join to a
  channel-backed virtual space.

  The token binds a nickname to a concrete channel name. `SpaceChannel` verifies
  it before touching the SessionServer, so the channel never trusts raw client
  input for identity.
  """

  @salt "channel_space_join"
  @max_age 3_600

  @spec sign(String.t(), integer() | nil, String.t()) :: String.t()
  def sign(channel_name, user_id, nickname) do
    data = %{channel_name: channel_name, user_id: user_id, nickname: nickname}
    Phoenix.Token.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t(), keyword()) ::
          {:ok, %{channel_name: String.t(), user_id: integer() | nil, nickname: String.t()}}
          | {:error, :expired | :invalid}
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
    Application.get_env(:retro_hex_chat, :p2p_token_secret) ||
      raise "Missing :p2p_token_secret configuration"
  end
end
