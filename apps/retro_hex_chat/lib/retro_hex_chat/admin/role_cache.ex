defmodule RetroHexChat.Admin.RoleCache do
  @moduledoc """
  GenServer owning ETS table for admin/server_operator role lookups.
  Seeded from DB on boot, updated on write.
  """
  use GenServer

  import Ecto.Query

  alias RetroHexChat.Admin.AdminRole
  alias RetroHexChat.Repo

  @table :admin_role_cache

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec admin?(String.t()) :: boolean()
  def admin?(nickname) do
    case :ets.lookup(@table, {nickname, "admin"}) do
      [_] -> true
      [] -> false
    end
  rescue
    ArgumentError -> false
  end

  @spec server_operator?(String.t()) :: boolean()
  def server_operator?(nickname) do
    case :ets.lookup(@table, {nickname, "server_operator"}) do
      [_] -> true
      [] -> false
    end
  rescue
    ArgumentError -> false
  end

  @spec add(String.t(), String.t()) :: true
  def add(nickname, role) do
    :ets.insert(@table, {{nickname, role}, true})
  end

  @spec remove(String.t(), String.t()) :: true
  def remove(nickname, role) do
    :ets.delete(@table, {nickname, role})
  end

  @spec remove_all(String.t()) :: :ok
  def remove_all(nickname) do
    :ets.delete(@table, {nickname, "admin"})
    :ets.delete(@table, {nickname, "server_operator"})
    :ok
  end

  @spec list_admin_nicks() :: [String.t()]
  def list_admin_nicks do
    :ets.match(@table, {{:"$1", "admin"}, :_})
    |> Enum.map(fn [nick] -> nick end)
  rescue
    ArgumentError -> []
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table])
    seed_from_db()
    {:ok, %{table: table}}
  end

  defp seed_from_db do
    from(r in AdminRole, select: {r.nickname, r.role})
    |> Repo.all()
    |> Enum.each(fn {nickname, role} ->
      :ets.insert(@table, {{nickname, role}, true})
    end)
  rescue
    _ -> :ok
  end
end
