defmodule RetroHexChat.Chat.IgnoreList do
  @moduledoc """
  Domain module for managing a user's ignore list.

  Provides in-memory CRUD operations on the ignore list map structure
  and persistence functions (save/2, load/1) for registered users.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.IgnoreEntry
  alias RetroHexChat.Chat.Schemas.IgnoreListEntry
  alias RetroHexChat.OwnedList
  alias RetroHexChat.Repo

  @max_entries 100
  @default_cleanup_limit 500

  @type cleanup_summary :: %{
          candidates: non_neg_integer(),
          deleted: non_neg_integer(),
          oldest_expires_at: DateTime.t() | nil,
          oldest_expired_age_ms: non_neg_integer() | nil
        }

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), String.t(), atom(), DateTime.t() | nil) ::
          {:ok, map()} | {:error, :list_full | :invalid_type}
  def add_entry(ignore_list, nickname, ignore_type, expires_at) do
    cond do
      not IgnoreEntry.valid_type?(ignore_type) ->
        {:error, :invalid_type}

      has_entry?(ignore_list, nickname) ->
        {:ok, upsert_entry(ignore_list, nickname, ignore_type, expires_at)}

      full?(ignore_list) ->
        {:error, :list_full}

      true ->
        entry =
          IgnoreEntry.new(
            nickname: nickname,
            ignore_type: ignore_type,
            expires_at: expires_at,
            created_at: DateTime.utc_now()
          )

        {:ok, %{ignore_list | entries: ignore_list.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(ignore_list, nickname) do
    downcased = String.downcase(nickname)

    case Enum.split_with(ignore_list.entries, fn e ->
           String.downcase(e.nickname) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_found, remaining} ->
        {:ok, %{ignore_list | entries: remaining}}
    end
  end

  @spec ignored?(map(), String.t(), atom()) :: boolean()
  def ignored?(ignore_list, nickname, message_type) do
    downcased = String.downcase(nickname)

    Enum.any?(ignore_list.entries, fn entry ->
      String.downcase(entry.nickname) == downcased and
        not IgnoreEntry.expired?(entry) and
        type_matches?(entry.ignore_type, message_type)
    end)
  end

  @spec get_entry(map(), String.t()) :: IgnoreEntry.t() | nil
  def get_entry(ignore_list, nickname) do
    downcased = String.downcase(nickname)

    Enum.find(ignore_list.entries, fn entry ->
      String.downcase(entry.nickname) == downcased
    end)
  end

  @spec update_nickname(map(), String.t(), String.t()) :: map()
  def update_nickname(ignore_list, old_nick, new_nick) do
    downcased_old = String.downcase(old_nick)

    updated_entries =
      Enum.map(ignore_list.entries, fn entry ->
        if String.downcase(entry.nickname) == downcased_old do
          %{entry | nickname: new_nick}
        else
          entry
        end
      end)

    %{ignore_list | entries: updated_entries}
  end

  @spec sorted_entries(map()) :: [IgnoreEntry.t()]
  def sorted_entries(ignore_list) do
    Enum.sort_by(ignore_list.entries, fn e -> String.downcase(e.nickname) end)
  end

  @spec count(map()) :: non_neg_integer()
  def count(ignore_list) do
    length(ignore_list.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(ignore_list) do
    count(ignore_list) >= @max_entries
  end

  @spec remove_expired(map()) :: {map(), [String.t()]}
  def remove_expired(ignore_list) do
    now = DateTime.utc_now()

    {expired, remaining} =
      Enum.split_with(ignore_list.entries, &IgnoreEntry.expired?(&1, now))

    expired_nicks = Enum.map(expired, & &1.nickname)
    {%{ignore_list | entries: remaining}, expired_nicks}
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, ignore_list) do
    now = DateTime.utc_now()
    entries = Enum.reject(ignore_list.entries, &IgnoreEntry.expired?(&1, now))

    OwnedList.replace(IgnoreListEntry, owner, entries, fn entry ->
      %{
        ignored_nickname: entry.nickname,
        ignore_type: Atom.to_string(entry.ignore_type),
        expires_at: entry.expires_at
      }
    end)
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    now = DateTime.utc_now()

    OwnedList.load(
      IgnoreListEntry,
      owner,
      &IgnoreEntry.new(
        nickname: &1.ignored_nickname,
        ignore_type: String.to_existing_atom(&1.ignore_type),
        expires_at: &1.expires_at,
        created_at: &1.inserted_at
      ),
      order_by: :inserted_at,
      keep: &(not expired_db_entry?(&1, now))
    )
  end

  @doc "Deletes expired durable ignore entries in bounded batches."
  @spec cleanup_expired_entries(keyword()) :: {:ok, cleanup_summary()} | {:error, term()}
  def cleanup_expired_entries(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    limit = positive_opt(opts, :limit, @default_cleanup_limit)

    Repo.transaction(fn ->
      entries = list_expired_entries(now, limit)
      ids = Enum.map(entries, & &1.id)

      %{
        candidates: length(entries),
        deleted: delete_expired_entries(ids, now),
        oldest_expires_at: oldest_expires_at(entries),
        oldest_expired_age_ms: oldest_expired_age_ms(entries, now)
      }
    end)
  end

  @doc "Counts expired durable ignore entries waiting for materialized cleanup."
  @spec expired_entry_count(keyword()) :: non_neg_integer()
  def expired_entry_count(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    IgnoreListEntry
    |> expired_entries_query(now)
    |> Repo.aggregate(:count, :id)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp list_expired_entries(now, limit) do
    IgnoreListEntry
    |> expired_entries_query(now)
    |> order_by([entry], asc: entry.expires_at, asc: entry.id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp delete_expired_entries([], _now), do: 0

  defp delete_expired_entries(ids, now) do
    {deleted, _records} =
      IgnoreListEntry
      |> where([entry], entry.id in ^ids)
      |> expired_entries_query(now)
      |> Repo.delete_all()

    deleted
  end

  defp expired_entries_query(queryable, now) do
    queryable
    |> where([entry], not is_nil(entry.expires_at))
    |> where([entry], entry.expires_at <= ^now)
  end

  defp expired_db_entry?(%IgnoreListEntry{expires_at: nil}, _now), do: false

  defp expired_db_entry?(%IgnoreListEntry{expires_at: %DateTime{} = expires_at}, now) do
    DateTime.compare(expires_at, now) != :gt
  end

  defp oldest_expires_at([]), do: nil
  defp oldest_expires_at([%IgnoreListEntry{expires_at: expires_at} | _entries]), do: expires_at

  defp oldest_expired_age_ms([], _now), do: nil

  defp oldest_expired_age_ms([%IgnoreListEntry{expires_at: expires_at} | _entries], now) do
    max(DateTime.diff(now, expires_at, :millisecond), 0)
  end

  defp positive_opt(opts, key, default) do
    case Keyword.get(opts, key, default) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
  end

  defp upsert_entry(ignore_list, nickname, ignore_type, expires_at) do
    downcased = String.downcase(nickname)

    updated_entries =
      Enum.map(ignore_list.entries, fn entry ->
        if String.downcase(entry.nickname) == downcased do
          %{entry | ignore_type: ignore_type, expires_at: expires_at}
        else
          entry
        end
      end)

    %{ignore_list | entries: updated_entries}
  end

  defp has_entry?(ignore_list, nickname) do
    get_entry(ignore_list, nickname) != nil
  end

  defp type_matches?(:all, _message_type), do: true
  defp type_matches?(:messages, :message), do: true
  defp type_matches?(:pms, :pm), do: true
  defp type_matches?(:actions, :action), do: true
  defp type_matches?(:invites, :invite), do: true
  defp type_matches?(:notices, :notice), do: true
  defp type_matches?(_ignore_type, _message_type), do: false
end
