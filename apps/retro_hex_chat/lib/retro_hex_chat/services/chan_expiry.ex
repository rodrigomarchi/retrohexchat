defmodule RetroHexChat.Services.ChanExpiry do
  @moduledoc "Periodic purge of inactive registered channels."
  use GenServer

  require Logger

  alias RetroHexChat.Services.Queries

  @default_expiration_days 7
  @default_purge_interval_ms 21_600_000

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    config = %{
      expiration_days: Keyword.get(opts, :expiration_days, @default_expiration_days),
      purge_interval_ms: Keyword.get(opts, :purge_interval_ms, @default_purge_interval_ms)
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
    names = Queries.list_expired_channel_names(state.expiration_days)

    Enum.each(names, &cleanup_channel/1)

    {count, purged_names} = Queries.purge_expired_channels(state.expiration_days)

    if count > 0 do
      Logger.info(
        "ChanExpiry: purged #{count} inactive channel(s): #{Enum.join(purged_names, ", ")}"
      )
    end

    {count, purged_names}
  end

  defp cleanup_channel(channel_name) do
    Queries.list_access(channel_name)
    |> Enum.each(fn entry -> Queries.remove_access(channel_name, entry.nickname) end)

    Queries.list_bans(channel_name)
    |> Enum.each(fn ban -> Queries.remove_ban(channel_name, ban.banned_nickname) end)

    Queries.list_ban_exceptions(channel_name)
    |> Enum.each(fn entry -> Queries.remove_ban_exception(channel_name, entry.nickname) end)

    Queries.list_invite_exceptions(channel_name)
    |> Enum.each(fn entry -> Queries.remove_invite_exception(channel_name, entry.nickname) end)

    Queries.delete_welcome_message(channel_name)
  end

  defp schedule_purge(interval_ms) do
    Process.send_after(self(), :purge, interval_ms)
  end
end
