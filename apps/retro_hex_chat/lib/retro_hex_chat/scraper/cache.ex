defmodule RetroHexChat.Scraper.Cache do
  @moduledoc """
  In-memory copy of recently read pages, and a claim on the ones being read.

  **Not the source of truth** — `RetroHexChat.Scraper.Store` is. This table only
  keeps a render path from crossing the network to Postgres for a page it asked
  about a moment ago, so it expires in an hour while the row behind it lives for
  120 days. A miss here costs one indexed read, not one HTTP request, which is
  why a short TTL is affordable and why nothing needs to invalidate it by hand.

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

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(opts) do
    table = Keyword.get(opts, :table_name, @default_table)
    _table = :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @spec page_key(String.t()) :: {:page, String.t()}
  defp page_key(url_hash), do: {:page, url_hash}

  @spec inflight_key(String.t()) :: {:inflight, String.t()}
  defp inflight_key(url_hash), do: {:inflight, url_hash}

  @spec now_ms() :: integer()
  defp now_ms, do: System.monotonic_time(:millisecond)
end
