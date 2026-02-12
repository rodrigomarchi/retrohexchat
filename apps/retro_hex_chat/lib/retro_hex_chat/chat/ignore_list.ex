defmodule RetroHexChat.Chat.IgnoreList do
  @moduledoc """
  Domain module for managing a user's ignore list.

  Provides in-memory CRUD operations on the ignore list map structure
  and persistence functions (save/2, load/1) for registered users.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.IgnoreEntry
  alias RetroHexChat.Chat.Schemas.IgnoreListEntry
  alias RetroHexChat.Repo

  @max_entries 100

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
    {expired, remaining} =
      Enum.split_with(ignore_list.entries, &IgnoreEntry.expired?/1)

    expired_nicks = Enum.map(expired, & &1.nickname)
    {%{ignore_list | entries: remaining}, expired_nicks}
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, ignore_list) do
    Repo.transaction(fn ->
      from(e in IgnoreListEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(ignore_list.entries, fn entry ->
        %IgnoreListEntry{}
        |> IgnoreListEntry.changeset(%{
          owner_nickname: owner,
          ignored_nickname: entry.nickname,
          ignore_type: Atom.to_string(entry.ignore_type),
          expires_at: entry.expires_at
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
    now = DateTime.utc_now()

    entries =
      from(e in IgnoreListEntry,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.inserted_at]
      )
      |> Repo.all()
      |> Enum.reject(fn db_entry ->
        db_entry.expires_at != nil and DateTime.compare(db_entry.expires_at, now) == :lt
      end)

    if entries == [] do
      {:error, :not_found}
    else
      domain_entries =
        Enum.map(entries, fn db_entry ->
          IgnoreEntry.new(
            nickname: db_entry.ignored_nickname,
            ignore_type: String.to_existing_atom(db_entry.ignore_type),
            expires_at: db_entry.expires_at,
            created_at: db_entry.inserted_at
          )
        end)

      {:ok, %{entries: domain_entries}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

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
