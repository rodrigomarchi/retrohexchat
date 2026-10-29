defmodule RetroHexChat.Radio.Cache do
  @moduledoc """
  The station lists Hex Radio asked for recently, kept for ten minutes.

  Everyone who opens a genre asks the same question; without this, each of them
  would cost Radio Browser a request. A list ten minutes old is as good as a
  fresh one — stations do not come and go by the minute — and a failed request
  is never kept, so the next reader asks again.

  Expiry is swept on a timer as well as checked on read, so a search nobody
  repeats does not stay resident.
  """

  use GenServer

  @table __MODULE__
  @ttl_ms :timer.minutes(10)
  @sweep_interval_ms :timer.minutes(5)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "The value kept under `key`, or `:miss` when there is none or it expired."
  @spec get(term()) :: {:ok, term()} | :miss
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, stored_at}] ->
        if now_ms() - stored_at < @ttl_ms, do: {:ok, value}, else: :miss

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  @doc "Keeps `value` under `key`."
  @spec put(term(), term()) :: :ok
  def put(key, value) do
    :ets.insert(@table, {key, value, now_ms()})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Empties the table."
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Drops every expired entry; returns how many."
  @spec sweep() :: non_neg_integer()
  def sweep do
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now_ms() - @ttl_ms}], [true]}])
  rescue
    ArgumentError -> 0
  end

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    _table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  @spec handle_info(:sweep, map()) :: {:noreply, map()}
  def handle_info(:sweep, state) do
    _dropped = sweep()
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)

  defp now_ms, do: System.monotonic_time(:millisecond)
end
