defmodule RetroHexChat.Chat.AutoJoinList do
  @moduledoc """
  Pure domain module for managing a user's auto-join channel list.

  Provides in-memory CRUD operations on the auto-join list map structure.
  Persistence functions (save/2, load/1) require database access.
  """

  alias RetroHexChat.Chat.AutoJoinEntry
  alias RetroHexChat.Chat.Schemas.AutojoinListEntry
  alias RetroHexChat.Repo

  import Ecto.Query

  @max_entries 20

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), String.t(), String.t() | nil) ::
          {:ok, map()} | {:error, atom()}
  def add_entry(autojoin_list, channel_name, channel_key \\ nil) do
    trimmed = String.trim(channel_name)

    cond do
      full?(autojoin_list) ->
        {:error, :list_full}

      not valid_channel?(trimmed) ->
        {:error, :invalid_channel}

      duplicate?(autojoin_list, trimmed) ->
        {:error, :duplicate}

      true ->
        position = next_position(autojoin_list)
        key = if channel_key && String.trim(channel_key) != "", do: String.trim(channel_key)

        entry =
          AutoJoinEntry.new(channel_name: trimmed, channel_key: key, position: position)

        {:ok, %{autojoin_list | entries: autojoin_list.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(autojoin_list, channel_name) do
    downcased = String.downcase(channel_name)

    case Enum.split_with(autojoin_list.entries, fn e ->
           String.downcase(e.channel_name) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        {:ok, %{autojoin_list | entries: reindex(rest)}}
    end
  end

  @spec update_entry(map(), String.t(), String.t() | nil) ::
          {:ok, map()} | {:error, :not_found}
  def update_entry(autojoin_list, channel_name, channel_key) do
    downcased = String.downcase(channel_name)
    key = if channel_key && String.trim(channel_key) != "", do: String.trim(channel_key)

    case find_and_update(autojoin_list.entries, downcased, key) do
      {:ok, updated_entries} ->
        {:ok, %{autojoin_list | entries: updated_entries}}

      :not_found ->
        {:error, :not_found}
    end
  end

  @spec clear(map()) :: {:ok, map()}
  def clear(autojoin_list) do
    {:ok, %{autojoin_list | entries: []}}
  end

  @spec entries(map()) :: [AutoJoinEntry.t()]
  def entries(autojoin_list) do
    Enum.sort_by(autojoin_list.entries, & &1.position)
  end

  @spec count(map()) :: non_neg_integer()
  def count(autojoin_list) do
    length(autojoin_list.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(autojoin_list) do
    count(autojoin_list) >= @max_entries
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, autojoin_list) do
    Repo.transaction(fn ->
      from(e in AutojoinListEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(autojoin_list.entries, fn entry ->
        %AutojoinListEntry{}
        |> AutojoinListEntry.changeset(%{
          owner_nickname: owner,
          channel_name: entry.channel_name,
          channel_key: entry.channel_key,
          position: entry.position
        })
        |> Repo.insert!()
      end)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    entries =
      from(e in AutojoinListEntry,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.position]
      )
      |> Repo.all()

    if entries == [] do
      {:error, :not_found}
    else
      domain_entries =
        Enum.map(entries, fn db_entry ->
          AutoJoinEntry.new(
            channel_name: db_entry.channel_name,
            channel_key: db_entry.channel_key,
            position: db_entry.position
          )
        end)

      {:ok, %{entries: domain_entries}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp valid_channel?(name) do
    String.starts_with?(name, "#") and
      String.length(name) >= 2 and
      not String.contains?(name, " ")
  end

  defp duplicate?(autojoin_list, channel_name) do
    downcased = String.downcase(channel_name)
    Enum.any?(autojoin_list.entries, fn e -> String.downcase(e.channel_name) == downcased end)
  end

  defp next_position(autojoin_list) do
    case autojoin_list.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp reindex(entries) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} -> %{entry | position: idx} end)
  end

  defp find_and_update(entries, downcased_name, key) do
    case Enum.split_while(entries, fn e -> String.downcase(e.channel_name) != downcased_name end) do
      {_before, []} ->
        :not_found

      {before, [target | after_list]} ->
        updated = %{target | channel_key: key}
        {:ok, before ++ [updated | after_list]}
    end
  end
end
