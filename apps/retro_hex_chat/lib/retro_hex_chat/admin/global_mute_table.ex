defmodule RetroHexChat.Admin.GlobalMuteTable do
  @moduledoc """
  ETS cache for durable global mute state.
  """

  use GenServer

  alias RetroHexChat.Admin.GlobalMutes

  @table :global_mutes

  @type cached_expiry :: :permanent | DateTime.t()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec muted?(String.t()) :: boolean()
  def muted?(nickname) do
    key = normalize(nickname)

    case :ets.lookup(@table, key) do
      [{^key, _nickname, :permanent}] ->
        true

      [{^key, _nickname, %DateTime{} = expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          true
        else
          :ets.delete(@table, key)
          false
        end

      [] ->
        false
    end
  rescue
    ArgumentError -> false
  end

  @spec mute(String.t(), cached_expiry()) :: :ok
  def mute(nickname, expiry) do
    :ets.insert(@table, {normalize(nickname), nickname, expiry})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec unmute(String.t()) :: :ok
  def unmute(nickname) do
    :ets.delete(@table, normalize(nickname))
    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec replace_all([{String.t(), cached_expiry()}]) :: :ok
  def replace_all(entries) do
    :ets.delete_all_objects(@table)

    Enum.each(entries, fn {nickname, expiry} ->
      :ets.insert(@table, {normalize(nickname), nickname, expiry})
    end)

    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec list_mutes() :: [{String.t(), cached_expiry()}]
  def list_mutes do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, nickname, expiry} -> {nickname, expiry} end)
  rescue
    ArgumentError -> []
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table])

    try do
      GlobalMutes.reload_cache()
    rescue
      _error -> :ok
    catch
      :exit, _reason -> :ok
    end

    {:ok, %{}}
  end

  defp normalize(nickname) when is_binary(nickname), do: String.downcase(nickname)
end
