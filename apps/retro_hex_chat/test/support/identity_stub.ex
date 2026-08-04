defmodule RetroHexChat.Bots.IdentityStub do
  @moduledoc """
  Treats every nickname as identified, so a test can decide who is an
  administrator with the `:admins` config alone.

  Identification and role are separate questions, and only the second is what
  the bot authorization tests are about. Answering the first for real would mean
  a NickServ registration and a bcrypt hash per case, which buys nothing: the
  production path still calls the real source, and `RetroHexChat.Bots.Policy`
  fails closed when it cannot be reached.
  """

  @behaviour RetroHexChat.Bots.Identity

  @impl true
  @spec identified?(String.t()) :: boolean()
  def identified?(_nickname), do: true
end
