defmodule RetroHexChat.Chat.LinkPreview.Cache do
  @moduledoc """
  ETS read-through cache for link preview titles.
  """
  use GenServer

  alias RetroHexChat.Chat.LinkPreview.Results

  @default_table __MODULE__
  @success_ttl_ms :timer.hours(1)
  @error_ttl_ms :timer.minutes(5)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec get(String.t(), atom()) :: {:ok, String.t() | nil | :error} | :miss
  def get(url, table \\ @default_table) do
    key = title_key(url)

    case :ets.lookup(table, key) do
      [{_, title, inserted_at, ttl}] ->
        if System.monotonic_time(:millisecond) - inserted_at < ttl do
          {:ok, title}
        else
          read_through(url, table)
        end

      [] ->
        read_through(url, table)
    end
  end

  @spec put(String.t(), String.t() | nil, atom()) :: :ok
  def put(url, title, table \\ @default_table) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(table, {title_key(url), title, now, @success_ttl_ms})
    :ets.delete(table, pending_key(url))
    :ok
  end

  @spec put_error(String.t(), atom()) :: :ok
  def put_error(url, table \\ @default_table) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(table, {title_key(url), :error, now, @error_ttl_ms})
    :ets.delete(table, pending_key(url))
    :ok
  end

  @spec pending?(String.t(), atom()) :: boolean()
  def pending?(url, table \\ @default_table) do
    :ets.lookup(table, pending_key(url)) != [] or durable_pending?(url, table)
  end

  @spec mark_pending(String.t(), atom()) :: :ok
  def mark_pending(url, table \\ @default_table) do
    :ets.insert(table, {pending_key(url), true})
    :ok
  end

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, @default_table)
    _table = :ets.new(table_name, [:named_table, :public, :set])
    {:ok, %{table: table_name}}
  end

  defp read_through(url, table) when table == @default_table do
    case Results.get_fresh(url) do
      {:ok, :error} = result ->
        put_error(url, table)
        result

      {:ok, title} = result ->
        put(url, title, table)
        result

      :miss ->
        :miss
    end
  end

  defp read_through(_url, _table), do: :miss

  defp durable_pending?(url, table) when table == @default_table, do: Results.pending?(url)
  defp durable_pending?(_url, _table), do: false

  defp title_key(url), do: {:title, cache_key(url)}
  defp pending_key(url), do: {:pending, cache_key(url)}

  defp cache_key(url) do
    case Results.hash_url(url) do
      {:ok, url_hash} -> url_hash
      {:error, :invalid_url} -> url
    end
  end
end
