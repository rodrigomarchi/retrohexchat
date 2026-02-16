defmodule RetroHexChat.P2P.CleanupTask do
  @moduledoc """
  Periodic background task that detects and expires stale P2P sessions
  whose GenServer processes are no longer running.
  """

  use GenServer

  require Logger

  alias RetroHexChat.P2P.{Queries, Registry}

  @default_interval :timer.minutes(1)
  @stale_threshold_minutes 30

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec run_cleanup() :: {:ok, non_neg_integer()}
  def run_cleanup do
    GenServer.call(__MODULE__, :run_cleanup)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, cleanup_interval())
    schedule_cleanup(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_call(:run_cleanup, _from, state) do
    count = do_cleanup()
    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    do_cleanup()
    schedule_cleanup(state.interval)
    {:noreply, state}
  end

  # --- Private Helpers ---

  defp do_cleanup do
    threshold = DateTime.add(DateTime.utc_now(), -@stale_threshold_minutes, :minute)
    stale_sessions = Queries.list_stale_sessions(threshold)

    expired_count =
      Enum.reduce(stale_sessions, 0, fn session, count ->
        case Registry.lookup(session.token) do
          {:error, :not_found} ->
            {:ok, _} = Queries.expire_session(session)

            Logger.info("Expired stale P2P session #{session.token} (status: #{session.status})")

            count + 1

          {:ok, _pid} ->
            # GenServer is running — leave it alone
            count
        end
      end)

    if expired_count > 0 do
      Logger.info("P2P cleanup: expired #{expired_count} stale sessions")
    end

    expired_count
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp cleanup_interval do
    Application.get_env(:retro_hex_chat, :p2p_cleanup_interval, @default_interval)
  end
end
