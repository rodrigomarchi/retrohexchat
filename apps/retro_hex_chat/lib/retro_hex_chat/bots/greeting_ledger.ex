defmodule RetroHexChat.Bots.GreetingLedger do
  @moduledoc """
  How the greeter learns whether it has met somebody before.

  Injected for the same reason `RetroHexChat.Bots.Identity` is: what the greeter
  *composes* — which lines go out, to whom, over which delivery — is a decision
  worth testing on its own, and routing every case through Postgres to reach it
  would test the wrong thing.

  Three answers, because a welcome has three cases:

  - `:first_time` — nobody by this name has been welcomed into this room by this
    bot. Only this case earns the announcement everyone in the room sees.
  - `:window_elapsed` — met before, but longer ago than the repeat window. The
    private welcome goes out again; the room hears nothing.
  - `:within_window` — just here. Silence.
  """

  @callback record(
              bot_id :: integer(),
              channel :: String.t(),
              nickname :: String.t(),
              window_sec :: non_neg_integer()
            ) :: :first_time | :window_elapsed | :within_window

  @doc "The ledger in force. Configure `:bot_greeting_ledger` to substitute one."
  @spec impl() :: module()
  def impl do
    Application.get_env(
      :retro_hex_chat,
      :bot_greeting_ledger,
      RetroHexChat.Bots.GreetingLedger.Durable
    )
  end
end
