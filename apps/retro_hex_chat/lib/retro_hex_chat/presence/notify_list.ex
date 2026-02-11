defmodule RetroHexChat.Presence.NotifyList do
  @moduledoc """
  Pure domain module for managing a user's notify (buddy) list.

  Provides in-memory CRUD operations on the notify list map structure,
  plus persistence functions that delegate to Ecto/Repo for database storage.
  """

  import Ecto.Query

  alias RetroHexChat.Presence.NotifyEntry
  alias RetroHexChat.Presence.NotifyListEntry
  alias RetroHexChat.Presence.NotifyListSettings
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ

  @max_entries 50
  @max_note_length 200

  # ---------------------------------------------------------------------------
  # In-Memory CRUD (T011)
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{entries: [], settings: %{auto_whois: false}}
  end

  @spec add_entry(map(), String.t(), String.t(), String.t() | nil) ::
          {:ok, map()} | {:error, :self_add | :duplicate | :list_full}
  def add_entry(notify_list, owner_nickname, tracked_nickname, note \\ nil) do
    cond do
      String.downcase(owner_nickname) == String.downcase(tracked_nickname) ->
        {:error, :self_add}

      tracking?(notify_list, tracked_nickname) ->
        {:error, :duplicate}

      full?(notify_list) ->
        {:error, :list_full}

      true ->
        entry = NotifyEntry.new(tracked_nickname: tracked_nickname, note: note)
        {:ok, %{notify_list | entries: notify_list.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(notify_list, tracked_nickname) do
    downcased = String.downcase(tracked_nickname)

    case Enum.split_with(notify_list.entries, fn e ->
           String.downcase(e.tracked_nickname) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_found, remaining} ->
        {:ok, %{notify_list | entries: remaining}}
    end
  end

  @spec update_note(map(), String.t(), String.t() | nil) :: {:ok, map()} | {:error, :not_found}
  def update_note(notify_list, tracked_nickname, note) do
    downcased = String.downcase(tracked_nickname)
    truncated_note = truncate_note(note)

    case find_and_update(notify_list.entries, downcased, fn entry ->
           %{entry | note: truncated_note}
         end) do
      {:ok, updated_entries} ->
        {:ok, %{notify_list | entries: updated_entries}}

      :not_found ->
        {:error, :not_found}
    end
  end

  @spec update_nickname(map(), String.t(), String.t()) :: map()
  def update_nickname(notify_list, old_nick, new_nick) do
    downcased = String.downcase(old_nick)

    updated_entries =
      Enum.map(notify_list.entries, fn entry ->
        if String.downcase(entry.tracked_nickname) == downcased do
          %{entry | tracked_nickname: new_nick}
        else
          entry
        end
      end)

    %{notify_list | entries: updated_entries}
  end

  @spec set_online(map(), String.t(), boolean()) :: map()
  def set_online(notify_list, tracked_nickname, online?) do
    downcased = String.downcase(tracked_nickname)

    updated_entries =
      Enum.map(notify_list.entries, fn entry ->
        if String.downcase(entry.tracked_nickname) == downcased do
          apply_online_status(entry, online?)
        else
          entry
        end
      end)

    %{notify_list | entries: updated_entries}
  end

  @spec set_auto_whois(map(), boolean()) :: map()
  def set_auto_whois(notify_list, auto_whois?) do
    %{notify_list | settings: %{notify_list.settings | auto_whois: auto_whois?}}
  end

  @spec tracking?(map(), String.t()) :: boolean()
  def tracking?(notify_list, nickname) do
    downcased = String.downcase(nickname)

    Enum.any?(notify_list.entries, fn entry ->
      String.downcase(entry.tracked_nickname) == downcased
    end)
  end

  @spec online_buddies(map()) :: [NotifyEntry.t()]
  def online_buddies(notify_list) do
    notify_list.entries
    |> Enum.filter(& &1.online)
    |> Enum.sort_by(&String.downcase(&1.tracked_nickname))
  end

  @spec offline_buddies(map()) :: [NotifyEntry.t()]
  def offline_buddies(notify_list) do
    notify_list.entries
    |> Enum.reject(& &1.online)
    |> Enum.sort_by(&String.downcase(&1.tracked_nickname))
  end

  @spec sorted_entries(map()) :: [NotifyEntry.t()]
  def sorted_entries(notify_list) do
    online_buddies(notify_list) ++ offline_buddies(notify_list)
  end

  @spec count(map()) :: non_neg_integer()
  def count(notify_list) do
    length(notify_list.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(notify_list) do
    count(notify_list) >= @max_entries
  end

  # ---------------------------------------------------------------------------
  # Whois Info (T035)
  # ---------------------------------------------------------------------------

  @spec whois_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  def whois_info(nickname) do
    case NickServ.info(nickname) do
      {:ok, info} ->
        {:ok,
         %{
           nickname: nickname,
           registered: true,
           identified: info.identified,
           registered_at: info.registered_at,
           last_seen_at: info.last_seen_at
         }}

      {:error, _} ->
        {:ok,
         %{
           nickname: nickname,
           registered: false,
           identified: false,
           registered_at: nil,
           last_seen_at: nil
         }}
    end
  end

  # ---------------------------------------------------------------------------
  # Persistence (T012)
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, notify_list) do
    Repo.transaction(fn ->
      # 1. Delete all existing entries for owner
      from(e in NotifyListEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      # 2. Insert all current entries
      now = DateTime.utc_now()

      Enum.each(notify_list.entries, fn entry ->
        %NotifyListEntry{}
        |> NotifyListEntry.changeset(%{
          owner_nickname: owner,
          tracked_nickname: entry.tracked_nickname,
          note: entry.note,
          last_seen_at: entry.last_seen_at
        })
        |> Ecto.Changeset.put_change(:inserted_at, now)
        |> Ecto.Changeset.put_change(:updated_at, now)
        |> Repo.insert!()
      end)

      # 3. Upsert settings
      upsert_settings(owner, notify_list.settings)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    entries =
      from(e in NotifyListEntry, where: e.owner_nickname == ^owner)
      |> Repo.all()

    settings = Repo.get(NotifyListSettings, owner)

    if entries == [] and is_nil(settings) do
      {:error, :not_found}
    else
      notify_entries =
        Enum.map(entries, fn db_entry ->
          NotifyEntry.new(
            tracked_nickname: db_entry.tracked_nickname,
            note: db_entry.note,
            last_seen_at: db_entry.last_seen_at,
            online: false
          )
        end)

      auto_whois = if settings, do: settings.auto_whois, else: false

      {:ok, %{entries: notify_entries, settings: %{auto_whois: auto_whois}}}
    end
  end

  @spec save_entry(String.t(), NotifyEntry.t()) :: :ok | {:error, term()}
  def save_entry(owner, entry) do
    owner_lower = String.downcase(owner)
    tracked_lower = String.downcase(entry.tracked_nickname)

    existing =
      from(e in NotifyListEntry,
        where:
          fragment("lower(?)", e.owner_nickname) == ^owner_lower and
            fragment("lower(?)", e.tracked_nickname) == ^tracked_lower
      )
      |> Repo.one()

    changeset_attrs = %{
      owner_nickname: owner,
      tracked_nickname: entry.tracked_nickname,
      note: entry.note,
      last_seen_at: entry.last_seen_at
    }

    result =
      if existing do
        existing
        |> NotifyListEntry.changeset(changeset_attrs)
        |> Repo.update()
      else
        %NotifyListEntry{}
        |> NotifyListEntry.changeset(changeset_attrs)
        |> Repo.insert()
      end

    case result do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec delete_entry(String.t(), String.t()) :: :ok
  def delete_entry(owner, tracked_nickname) do
    owner_lower = String.downcase(owner)
    tracked_lower = String.downcase(tracked_nickname)

    from(e in NotifyListEntry,
      where:
        fragment("lower(?)", e.owner_nickname) == ^owner_lower and
          fragment("lower(?)", e.tracked_nickname) == ^tracked_lower
    )
    |> Repo.delete_all()

    :ok
  end

  @spec save_settings(String.t(), map()) :: :ok | {:error, term()}
  def save_settings(owner, settings) do
    case upsert_settings(owner, settings) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec apply_online_status(NotifyEntry.t(), boolean()) :: NotifyEntry.t()
  defp apply_online_status(entry, true), do: %{entry | online: true}

  defp apply_online_status(entry, false),
    do: %{entry | online: false, last_seen_at: DateTime.utc_now()}

  @spec truncate_note(String.t() | nil) :: String.t() | nil
  defp truncate_note(nil), do: nil

  defp truncate_note(note) when is_binary(note) do
    String.slice(note, 0, @max_note_length)
  end

  @spec find_and_update([NotifyEntry.t()], String.t(), (NotifyEntry.t() -> NotifyEntry.t())) ::
          {:ok, [NotifyEntry.t()]} | :not_found
  defp find_and_update(entries, downcased_nick, update_fn) do
    {found, updated} =
      Enum.reduce(entries, {false, []}, fn entry, {found?, acc} ->
        if String.downcase(entry.tracked_nickname) == downcased_nick do
          {true, [update_fn.(entry) | acc]}
        else
          {found?, [entry | acc]}
        end
      end)

    if found do
      {:ok, Enum.reverse(updated)}
    else
      :not_found
    end
  end

  @spec upsert_settings(String.t(), map()) :: {:ok, NotifyListSettings.t()} | {:error, term()}
  defp upsert_settings(owner, settings) do
    auto_whois = Map.get(settings, :auto_whois, false)

    case Repo.get(NotifyListSettings, owner) do
      nil ->
        %NotifyListSettings{}
        |> NotifyListSettings.changeset(%{owner_nickname: owner, auto_whois: auto_whois})
        |> Repo.insert()

      existing ->
        existing
        |> NotifyListSettings.changeset(%{auto_whois: auto_whois})
        |> Repo.update()
    end
  end
end
