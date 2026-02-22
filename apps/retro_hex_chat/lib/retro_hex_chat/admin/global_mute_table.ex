defmodule RetroHexChat.Admin.GlobalMuteTable do
  @moduledoc """
  GenServer owning ETS table for global mute state.
  Entries are ephemeral — they do not survive restarts.
  """
  use GenServer

  @table :global_mutes

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec muted?(String.t()) :: boolean()
  def muted?(nickname) do
    case :ets.lookup(@table, nickname) do
      [{^nickname, :permanent}] -> true
      [{^nickname, expires_at}] -> System.monotonic_time(:millisecond) < expires_at
      [] -> false
    end
  rescue
    ArgumentError -> false
  end

  @spec mute(String.t(), non_neg_integer() | :permanent) :: :ok
  def mute(nickname, :permanent) do
    :ets.insert(@table, {nickname, :permanent})
    :ok
  end

  def mute(nickname, duration_seconds) do
    expires_at = System.monotonic_time(:millisecond) + duration_seconds * 1000
    :ets.insert(@table, {nickname, expires_at})
    :ok
  end

  @spec unmute(String.t()) :: :ok
  def unmute(nickname) do
    :ets.delete(@table, nickname)
    :ok
  end

  @spec list_mutes() :: [{String.t(), :permanent | integer()}]
  def list_mutes do
    :ets.tab2list(@table)
  rescue
    ArgumentError -> []
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table])
    {:ok, %{}}
  end
end
