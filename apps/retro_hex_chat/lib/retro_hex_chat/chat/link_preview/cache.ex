defmodule RetroHexChat.Chat.LinkPreview.Cache do
  @moduledoc """
  ETS-based cache for link preview titles.
  """
  use GenServer

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
    case :ets.lookup(table, {:title, url}) do
      [{_, title, inserted_at, ttl}] ->
        if System.monotonic_time(:millisecond) - inserted_at < ttl do
          {:ok, title}
        else
          :miss
        end

      [] ->
        :miss
    end
  end

  @spec put(String.t(), String.t() | nil, atom()) :: :ok
  def put(url, title, table \\ @default_table) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(table, {{:title, url}, title, now, @success_ttl_ms})
    :ets.delete(table, {:pending, url})
    :ok
  end

  @spec put_error(String.t(), atom()) :: :ok
  def put_error(url, table \\ @default_table) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(table, {{:title, url}, :error, now, @error_ttl_ms})
    :ets.delete(table, {:pending, url})
    :ok
  end

  @spec pending?(String.t(), atom()) :: boolean()
  def pending?(url, table \\ @default_table) do
    :ets.lookup(table, {:pending, url}) != []
  end

  @spec mark_pending(String.t(), atom()) :: :ok
  def mark_pending(url, table \\ @default_table) do
    :ets.insert(table, {{:pending, url}, true})
    :ok
  end

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, @default_table)
    _table = :ets.new(table_name, [:named_table, :public, :set])
    {:ok, %{table: table_name}}
  end
end
