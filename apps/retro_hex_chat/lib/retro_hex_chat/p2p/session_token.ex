defmodule RetroHexChat.P2P.SessionToken do
  @moduledoc """
  Token generation and verification for P2P sessions.
  Uses Phoenix.Token with a dedicated salt.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @salt "p2p_session"
  @max_age 86_400

  @spec sign(integer(), integer(), integer()) :: String.t()
  def sign(creator_id, peer_id, session_id) do
    data = %{creator_id: creator_id, peer_id: peer_id, session_id: session_id}
    Phoenix.Token.sign(secret_key_base(), @salt, data)
  end

  @spec verify(String.t()) ::
          {:ok, %{creator_id: integer(), peer_id: integer(), session_id: integer()}}
          | {:error, :expired | :invalid}
  def verify(token) do
    case Phoenix.Token.verify(secret_key_base(), @salt, token, max_age: @max_age) do
      {:ok, data} -> {:ok, data}
      {:error, :expired} -> {:error, :expired}
      {:error, _reason} -> {:error, :invalid}
    end
  end

  defp secret_key_base do
    Application.get_env(:retro_hex_chat, :p2p_token_secret) ||
      raise dgettext("p2p", "Missing :p2p_token_secret configuration")
  end
end
