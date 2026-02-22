defmodule RetroHexChat.Admin.BanCache do
  @moduledoc """
  GenServer owning ETS table for O(1) server ban lookups.
  Seeded from DB on boot, updated on write.
  """
  use GenServer

  alias RetroHexChat.Admin.ServerBans

  @table :server_ban_cache

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec banned?(String.t()) :: boolean()
  def banned?(nickname) do
    case :ets.lookup(@table, nickname) do
      [{^nickname, _}] -> true
      [] -> false
    end
  rescue
    ArgumentError -> false
  end

  @spec add(String.t(), DateTime.t() | nil) :: true
  def add(nickname, expires_at \\ nil) do
    :ets.insert(@table, {nickname, expires_at})
  end

  @spec remove(String.t()) :: true
  def remove(nickname) do
    :ets.delete(@table, nickname)
  end

  @spec list() :: [{String.t(), DateTime.t() | nil}]
  def list do
    :ets.tab2list(@table)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table])
    seed_from_db()
    {:ok, %{table: table}}
  end

  defp seed_from_db do
    ServerBans.list_active_bans()
    |> Enum.each(fn ban ->
      :ets.insert(@table, {ban.nickname, ban.expires_at})
    end)
  rescue
    _ -> :ok
  end
end
