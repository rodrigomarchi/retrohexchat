defmodule RetroHexChat.Presence.WhowasCache do
  @moduledoc """
  GenServer-backed ETS cache for recently disconnected users.
  Entries expire after 1 hour. Maximum 1000 entries with oldest eviction.
  Periodic cleanup runs every 10 minutes.
  """
  use GenServer

  alias RetroHexChat.Services.Queries

  @table :whowas_cache
  @default_ttl_seconds 3600
  @ttl_setting_key "whowas_retention_seconds"
  @max_entries 1000
  @cleanup_interval_ms 600_000

  # ── Client API ───────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec record(String.t(), [String.t()], String.t() | nil) :: :ok
  def record(nickname, channels, quit_message \\ nil) do
    entry = %{
      nickname: nickname,
      channels: channels,
      quit_message: quit_message,
      disconnected_at: DateTime.utc_now()
    }

    key = String.downcase(nickname)
    :ets.insert(@table, {key, entry})
    enforce_capacity()
    :ok
  end

  @spec lookup(String.t()) :: {:ok, map()} | {:error, :not_found}
  def lookup(nickname) do
    key = String.downcase(nickname)

    case :ets.lookup(@table, key) do
      [{^key, entry}] ->
        if expired?(entry) do
          :ets.delete(@table, key)
          {:error, :not_found}
        else
          {:ok, entry}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @spec size() :: non_neg_integer()
  def size do
    :ets.info(@table, :size)
  end

  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  # ── Server Callbacks ─────────────────────────────────────────

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, @table)

    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    schedule_cleanup()
    {:ok, %{table: table_name}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired(state.table)
    schedule_cleanup()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ──────────────────────────────────────────────────

  @spec expired?(map()) :: boolean()
  defp expired?(%{disconnected_at: disconnected_at}) do
    DateTime.diff(DateTime.utc_now(), disconnected_at, :second) > ttl_seconds()
  end

  @spec enforce_capacity() :: :ok
  defp enforce_capacity do
    current_size = :ets.info(@table, :size)

    if current_size > @max_entries do
      evict_oldest()
    end

    :ok
  end

  @spec evict_oldest() :: :ok
  defp evict_oldest do
    all_entries =
      :ets.tab2list(@table)
      |> Enum.sort_by(fn {_key, entry} -> entry.disconnected_at end, DateTime)

    to_remove = length(all_entries) - @max_entries

    all_entries
    |> Enum.take(to_remove)
    |> Enum.each(fn {key, _entry} -> :ets.delete(@table, key) end)

    :ok
  end

  @spec cleanup_expired(atom()) :: :ok
  defp cleanup_expired(table) do
    now = DateTime.utc_now()
    ttl = ttl_seconds()

    :ets.tab2list(table)
    |> Enum.each(fn {key, entry} ->
      if DateTime.diff(now, entry.disconnected_at, :second) > ttl do
        :ets.delete(table, key)
      end
    end)

    :ok
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp ttl_seconds do
    case configured_ttl_setting() do
      nil ->
        @default_ttl_seconds

      value ->
        parse_ttl_seconds(value)
    end
  end

  defp parse_ttl_seconds(value) do
    case Integer.parse(value) do
      {seconds, ""} when seconds > 0 -> seconds
      _ -> @default_ttl_seconds
    end
  end

  defp configured_ttl_setting do
    Queries.get_setting(@ttl_setting_key)
  rescue
    DBConnection.OwnershipError -> nil
  catch
    :exit, _reason -> nil
  end
end
