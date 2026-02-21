defmodule RetroHexChat.Services.NickExpiry do
  @moduledoc "Periodic purge of inactive registered nicknames."
  use GenServer

  require Logger

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  @default_expiration_days 7
  @default_purge_interval_ms 21_600_000

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    config = %{
      expiration_days: Keyword.get(opts, :expiration_days, @default_expiration_days),
      purge_interval_ms: Keyword.get(opts, :purge_interval_ms, @default_purge_interval_ms),
      nickserv: Keyword.get(opts, :nickserv, NickServ)
    }

    GenServer.start_link(__MODULE__, config, name: name)
  end

  @spec run_now(GenServer.server()) :: {non_neg_integer(), [String.t()]}
  def run_now(server \\ __MODULE__) do
    GenServer.call(server, :run_now)
  end

  # -- GenServer callbacks --

  @impl true
  def init(config) do
    schedule_purge(config.purge_interval_ms)
    {:ok, config}
  end

  @impl true
  def handle_call(:run_now, _from, state) do
    result = do_purge(state)
    {:reply, result, state}
  end

  @impl true
  def handle_info(:purge, state) do
    do_purge(state)
    schedule_purge(state.purge_interval_ms)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private --

  defp do_purge(state) do
    protected = NickServ.list_identified(state.nickserv)
    {count, nicknames} = Queries.purge_expired_nicks(state.expiration_days, protected)

    Enum.each(nicknames, fn nick ->
      NickServ.remove_identified(nick, state.nickserv)
    end)

    if count > 0 do
      Logger.info("NickExpiry: purged #{count} inactive nick(s): #{Enum.join(nicknames, ", ")}")
    end

    {count, nicknames}
  end

  defp schedule_purge(interval_ms) do
    Process.send_after(self(), :purge, interval_ms)
  end
end
