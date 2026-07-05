defmodule RetroHexChat.VirtualSpace.CleanupTask do
  @moduledoc """
  Periodic background task that expires overdue virtual space sessions whose
  GenServer processes are no longer running. A registered process owns the
  expiry of its own session, so it is skipped here.
  """

  use GenServer

  require Logger

  alias RetroHexChat.VirtualSpace.{Queries, Registry}

  @default_interval :timer.minutes(1)

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec run_cleanup() :: {:ok, non_neg_integer()}
  def run_cleanup do
    GenServer.call(__MODULE__, :run_cleanup)
  end

  # --- GenServer callbacks ---

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

  # --- Private helpers ---

  defp do_cleanup do
    overdue_sessions = Queries.list_expired_sessions(DateTime.utc_now())

    expired_count =
      Enum.reduce(overdue_sessions, 0, fn session, count ->
        case Registry.lookup(session.token) do
          {:error, :not_found} ->
            {:ok, _} = Queries.expire_session(session)
            Logger.info("Expired overdue virtual space #{session.token}")
            count + 1

          {:ok, _pid} ->
            count
        end
      end)

    if expired_count > 0 do
      Logger.info("VirtualSpace cleanup: expired #{expired_count} sessions")
    end

    expired_count
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp cleanup_interval do
    Application.get_env(:retro_hex_chat, :virtual_space_cleanup_interval, @default_interval)
  end
end
