defmodule RetroHexChat.Bots.GreetingLedgerStub do
  @moduledoc """
  Answers the greeter's "have we met?" without a database.

  What the greeter decides — which lines go out, to whom, over which delivery —
  is worth testing on its own, and it has three branches that differ only by this
  answer. Going through Postgres to reach them would make a composition test into
  a persistence test, and `RetroHexChat.Bots.Queries.record_greeting/4` is where
  the persistence is proved.

  Says `:first_time` unless a test says otherwise. `put_answer/1` steers it for
  the calling process only, which keeps capability tests async. A greeter running
  inside a bot's GenServer is a different process and cannot be reached that way,
  so `set_answer/1` steers it for everyone — only safe from an `async: false`
  test, and `reset/0` puts it back.
  """

  @behaviour RetroHexChat.Bots.GreetingLedger

  @key :bot_greeting_ledger_stub_answer

  @type answer :: :first_time | :window_elapsed | :within_window

  @doc "Makes this process's greetings resolve to `answer`."
  @spec put_answer(answer()) :: :ok
  def put_answer(answer) when answer in [:first_time, :window_elapsed, :within_window] do
    Process.put(@key, answer)
    :ok
  end

  @doc "Makes every process's greetings resolve to `answer`. `async: false` only."
  @spec set_answer(answer()) :: :ok
  def set_answer(answer) when answer in [:first_time, :window_elapsed, :within_window] do
    Application.put_env(:retro_hex_chat, @key, answer)
  end

  @doc "Drops a global override set by `set_answer/1`."
  @spec reset() :: :ok
  def reset, do: Application.delete_env(:retro_hex_chat, @key)

  @impl true
  @spec record(integer(), String.t(), String.t(), non_neg_integer()) :: answer()
  def record(_bot_id, _channel, _nickname, _window_sec) do
    Process.get(@key) || Application.get_env(:retro_hex_chat, @key, :first_time)
  end
end
