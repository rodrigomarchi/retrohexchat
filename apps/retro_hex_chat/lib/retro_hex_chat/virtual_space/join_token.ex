defmodule RetroHexChat.VirtualSpace.JoinToken do
  @moduledoc """
  Short-lived signed token that authorizes a Phoenix Channel join to a
  virtual space. `SpaceLive` signs it after running the join policy; the
  `SpaceChannel` verifies it before touching the SessionServer, so the
  channel never trusts raw client input for identity.
  """

  @salt "space_join"
  @max_age 3_600

  @spec sign(String.t(), integer(), String.t()) :: String.t()
  def sign(space_token, user_id, nickname) do
    data = %{space_token: space_token, user_id: user_id, nickname: nickname}
    Phoenix.Token.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t(), keyword()) ::
          {:ok, %{space_token: String.t(), user_id: integer(), nickname: String.t()}}
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
