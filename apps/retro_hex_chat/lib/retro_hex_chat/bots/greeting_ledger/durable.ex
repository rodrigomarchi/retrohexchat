defmodule RetroHexChat.Bots.GreetingLedger.Durable do
  @moduledoc """
  The greeting ledger backed by `bot_greetings`.

  A row per person per room per bot, which is what makes the announcement survive
  a deploy. The in-memory window it replaces on the join path lived in the bot's
  GenServer state and reset every time the release restarted — invisible while
  every greeting was a private notice, and a hundred and forty-four bots
  announcing every returning reader the moment one of them became public.
  """

  @behaviour RetroHexChat.Bots.GreetingLedger

  alias RetroHexChat.Bots.Queries

  @impl true
  @spec record(integer(), String.t(), String.t(), non_neg_integer()) ::
          :first_time | :window_elapsed | :within_window
  def record(bot_id, channel, nickname, window_sec) do
    Queries.record_greeting(bot_id, channel, nickname, window_sec)
  end
end
