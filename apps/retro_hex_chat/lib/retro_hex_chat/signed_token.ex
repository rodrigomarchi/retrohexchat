defmodule RetroHexChat.SignedToken do
  @moduledoc """
  A short-lived signed token, and what it means when one does not check out.

  Two doors are opened by one of these: a raw Phoenix Channel carrying the
  SDP and ICE of a group call, and a channel-backed virtual space. Each mints a
  token when the person is already known to the LiveView, and the channel on the
  other side verifies it rather than trusting anything the client says about who
  it is.

  Verification tells expiry apart from everything else and says nothing further.
  A token that ran out is an ordinary thing — the person left the tab open —
  and the caller can offer a fresh one. Every other failure is `:invalid`,
  deliberately without a reason: a client that learns *why* a forgery was
  rejected learns how to forge better, and the channel that receives this has
  one thing to do with anything that is not `{:ok, _}` regardless.

  What each caller keeps is its own salt, its own secret, and the data it binds.
  The salt is not decoration: it goes into the key derivation, so two kinds of
  token signed with the same secret cannot be spent on each other's door.
  """

  @default_max_age 3_600

  @doc "An hour, which is how long a token is good for unless a caller says otherwise."
  @spec default_max_age() :: pos_integer()
  def default_max_age, do: @default_max_age

  @doc "A token binding `data`, readable only by someone holding `secret` and `salt`."
  @spec sign(binary(), binary(), term()) :: binary()
  def sign(secret, salt, data), do: Phoenix.Token.sign(secret, salt, data)

  @doc """
  What the token said, if it is still good.

  `:expired` for one that ran out, `:invalid` for anything else — a forgery, a
  token minted for another door, a string that was never a token at all.
  """
  @spec verify(binary(), binary(), binary(), keyword()) ::
          {:ok, term()} | {:error, :expired | :invalid}
  def verify(secret, salt, token, opts \\ []) do
    max_age = Keyword.get(opts, :max_age, @default_max_age)

    case Phoenix.Token.verify(secret, salt, token, max_age: max_age) do
      {:ok, data} -> {:ok, data}
      {:error, :expired} -> {:error, :expired}
      {:error, _reason} -> {:error, :invalid}
    end
  end
end
