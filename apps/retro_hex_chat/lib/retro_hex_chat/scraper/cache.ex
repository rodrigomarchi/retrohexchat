defmodule RetroHexChat.Scraper.Cache do
  @moduledoc """
  In-memory copy of recently read pages, and a claim on the ones being read.

  **Not the source of truth** — `RetroHexChat.Scraper.Store` is. This table only
  keeps a render path from crossing the network to Postgres for a page it asked
  about a moment ago, so it expires in an hour while the row behind it lives for
  120 days. A miss here costs one indexed read, not one HTTP request, which is
  why a short TTL is affordable and why nothing needs to invalidate it by hand.

  **Expiry is swept, not only read.** Checking an entry's age when somebody asks
  for it never serves a stale page, and never frees one either: a page nobody
  asks about again is never looked up, so nothing notices that it expired and it
  stays resident. With feeds scraped around the clock that is a table that only
  grows, and it grew until the machine had no memory left. The server sweeps on
  a timer, so the table's size follows what is being read rather than everything
  that was ever read.

  It also carries the in-flight claim. `:ets.insert_new/2` is atomic, so the first
  process to claim a URL is the only one that fetches it; the rest read what is
  already stored rather than opening a second connection to the same publisher.
  That is a collapse, not a lock — losing the claim costs one duplicated request,
  which the store's upsert converges.
  """

  use GenServer

  alias RetroHexChat.Scraper.ScrapedPage

  @default_table __MODULE__
  @page_ttl_ms :timer.hours(1)
  @inflight_ttl_ms :timer.seconds(30)

  # Comfortably shorter than the page TTL: a sweep slower than the life of what
  # it collects lets a whole generation pile up between passes.
  @sweep_interval_ms :timer.minutes(5)

  @doc "How long a cached page is served before it has to be read again."
  @spec page_ttl_ms() :: pos_integer()
  def page_ttl_ms, do: @page_ttl_ms

  @doc "How long a fetch claim stands before it is treated as abandoned."
  @spec inflight_ttl_ms() :: pos_integer()
  def inflight_ttl_ms, do: @inflight_ttl_ms

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "The page cached for `url_hash`, if it was cached recently enough."
  @spec get(String.t(), atom()) :: {:ok, ScrapedPage.t()} | :miss
  def get(url_hash, table \\ @default_table) do
    case :ets.lookup(table, page_key(url_hash)) do
      [{_key, page, cached_at}] ->
        if now_ms() - cached_at < @page_ttl_ms, do: {:ok, page}, else: :miss

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  @spec put(ScrapedPage.t(), atom()) :: :ok
  def put(%ScrapedPage{url_hash: url_hash} = page, table \\ @default_table) do
    :ets.insert(table, {page_key(url_hash), page, now_ms()})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec forget(String.t(), atom()) :: :ok
  def forget(url_hash, table \\ @default_table) do
    :ets.delete(table, page_key(url_hash))
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Claims the right to fetch `url_hash`.

  Returns `:ok` to exactly one caller while the claim stands. A claim older than
  the fetch budget is treated as abandoned, so a process that died mid-fetch
  cannot wedge a URL shut.
  """
  @spec claim(String.t(), atom()) :: :ok | :taken
  def claim(url_hash, table \\ @default_table) do
    now = now_ms()
    key = inflight_key(url_hash)

    if :ets.insert_new(table, {key, now}) do
      :ok
    else
      case :ets.lookup(table, key) do
        [{_key, claimed_at}] when now - claimed_at >= @inflight_ttl_ms ->
          :ets.insert(table, {key, now})
          :ok

        _still_running ->
          :taken
      end
    end
  rescue
    ArgumentError -> :ok
  end

  @spec release(String.t(), atom()) :: :ok
  def release(url_hash, table \\ @default_table) do
    :ets.delete(table, inflight_key(url_hash))
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Empties the table. The stored pages are untouched."
  @spec clear(atom()) :: :ok
  def clear(table \\ @default_table) do
    :ets.delete_all_objects(table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Drops every entry that has outlived its kind. Returns how many it removed.

  Public because it is the whole point of this module's periodic work, and a
  test that had to wait an hour to watch it happen would not be written.
  """
  @spec sweep(atom()) :: non_neg_integer()
  def sweep(table \\ @default_table) do
    now = now_ms()

    :ets.select_delete(table, [
      {{{:page, :_}, :_, :"$1"}, [{:<, :"$1", now - @page_ttl_ms}], [true]},
      {{{:inflight, :_}, :"$1"}, [{:<, :"$1", now - @inflight_ttl_ms}], [true]}
    ])
  rescue
    ArgumentError -> 0
  end

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(opts) do
    table = Keyword.get(opts, :table_name, @default_table)
    _table = :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    schedule_sweep()
    {:ok, %{table: table}}
  end

  @impl true
  @spec handle_info(:sweep, map()) :: {:noreply, map()}
  def handle_info(:sweep, %{table: table} = state) do
    _dropped = sweep(table)
    schedule_sweep()
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @spec schedule_sweep() :: reference()
  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)

  @spec page_key(String.t()) :: {:page, String.t()}
  defp page_key(url_hash), do: {:page, url_hash}

  @spec inflight_key(String.t()) :: {:inflight, String.t()}
  defp inflight_key(url_hash), do: {:inflight, url_hash}

  @spec now_ms() :: integer()
  defp now_ms, do: System.monotonic_time(:millisecond)
end
