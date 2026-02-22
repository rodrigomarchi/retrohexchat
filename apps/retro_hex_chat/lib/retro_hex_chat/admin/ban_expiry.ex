defmodule RetroHexChat.Admin.BanExpiry do
  @moduledoc "Periodic task to expire time-limited server bans."
  use GenServer

  require Logger

  alias RetroHexChat.Admin.ServerBans

  @default_interval_ms 3_600_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    GenServer.start_link(__MODULE__, %{interval_ms: interval}, name: name)
  end

  @impl true
  def init(config) do
    schedule(config.interval_ms)
    {:ok, config}
  end

  @impl true
  def handle_info(:expire, state) do
    count = ServerBans.expire_bans()

    if count > 0 do
      Logger.info("BanExpiry: expired #{count} ban(s)")
    end

    schedule(state.interval_ms)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp schedule(interval_ms) do
    Process.send_after(self(), :expire, interval_ms)
  end
end
