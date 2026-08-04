defmodule RetroHexChat.Bots.Identity do
  @moduledoc """
  How bot authorization learns whether a nickname is identified.

  Injected for the same reason the RSS fetcher is: the interesting behaviour is
  what authorization *decides* — an operator refused, an administrator obeyed —
  and proving that should not require registering a nick and paying bcrypt once
  per case. The real implementation asks NickServ, which is the busiest process
  on the server; a test that went through it would be measuring the wrong thing
  and would be slow while doing it.
  """

  @callback identified?(nickname :: String.t()) :: boolean()

  @doc "The identity source in force. Configure `:bot_identity` to substitute one."
  @spec impl() :: module()
  def impl do
    Application.get_env(:retro_hex_chat, :bot_identity, RetroHexChat.Services.Policy)
  end
end
