defmodule RetroHexChat.Accounts.ContactList do
  @moduledoc """
  Pure domain module for managing a user's address book (contact list).

  Provides in-memory CRUD operations on the contact list map structure,
  plus persistence functions that delegate to Ecto/Repo for database storage.
  """
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  alias RetroHexChat.Accounts.Contact
  alias RetroHexChat.Accounts.ContactEntry
  alias RetroHexChat.NicknameList
  alias RetroHexChat.Repo

  @list NicknameList.new(field: :contact_nickname, max_entries: 100, max_note_length: 200)
  @max_nickname_length 16

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), String.t(), String.t(), String.t() | nil) ::
          {:ok, map()} | {:error, :self_add | :duplicate | :list_full | :invalid_nickname}
  def add_entry(contact_list, owner_nickname, contact_nickname, note \\ nil) do
    cond do
      not valid_nickname?(contact_nickname) ->
        {:error, :invalid_nickname}

      String.downcase(owner_nickname) == String.downcase(contact_nickname) ->
        {:error, :self_add}

      NicknameList.member?(@list, contact_list, contact_nickname) ->
        {:error, :duplicate}

      full?(contact_list) ->
        {:error, :list_full}

      true ->
        entry =
          Contact.new(
            contact_nickname: contact_nickname,
            note: NicknameList.truncate_note(@list, note),
            first_contact_date: DateTime.utc_now()
          )

        {:ok, %{contact_list | entries: contact_list.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(contact_list, contact_nickname),
    do: NicknameList.remove(@list, contact_list, contact_nickname)

  @spec update_note(map(), String.t(), String.t() | nil) :: {:ok, map()} | {:error, :not_found}
  def update_note(contact_list, contact_nickname, note),
    do: NicknameList.put_note(@list, contact_list, contact_nickname, note)

  @spec sorted_entries(map()) :: [Contact.t()]
  def sorted_entries(contact_list) do
    NicknameList.sorted(@list, contact_list.entries)
  end

  @spec count(map()) :: non_neg_integer()
  def count(contact_list) do
    length(contact_list.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(contact_list) do
    NicknameList.full?(@list, contact_list)
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, contact_list) do
    Repo.transaction(fn ->
      # 1. Delete all existing entries for owner
      from(e in ContactEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      # 2. Insert all current entries
      now = DateTime.utc_now()

      Enum.each(contact_list.entries, fn entry ->
        %ContactEntry{}
        |> ContactEntry.changeset(%{
          owner_nickname: owner,
          contact_nickname: entry.contact_nickname,
          note: entry.note,
          first_contact_date: entry.first_contact_date
        })
        |> Ecto.Changeset.put_change(:inserted_at, now)
        |> Ecto.Changeset.put_change(:updated_at, now)
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
      from(e in ContactEntry, where: e.owner_nickname == ^owner)
      |> Repo.all()

    if entries == [] do
      {:error, :not_found}
    else
      contacts =
        Enum.map(entries, fn db_entry ->
          Contact.new(
            contact_nickname: db_entry.contact_nickname,
            note: db_entry.note,
            first_contact_date: db_entry.first_contact_date
          )
        end)

      {:ok, %{entries: contacts}}
    end
  end

  @spec save_entry(String.t(), Contact.t()) :: :ok | {:error, term()}
  def save_entry(owner, entry) do
    owner_lower = String.downcase(owner)
    contact_lower = String.downcase(entry.contact_nickname)

    existing =
      from(e in ContactEntry,
        where:
          fragment("lower(?)", e.owner_nickname) == ^owner_lower and
            fragment("lower(?)", e.contact_nickname) == ^contact_lower
      )
      |> Repo.one()

    changeset_attrs = %{
      owner_nickname: owner,
      contact_nickname: entry.contact_nickname,
      note: entry.note,
      first_contact_date: entry.first_contact_date
    }

    result =
      if existing do
        existing
        |> ContactEntry.changeset(changeset_attrs)
        |> Repo.update()
      else
        %ContactEntry{}
        |> ContactEntry.changeset(changeset_attrs)
        |> Repo.insert()
      end

    case result do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec delete_entry(String.t(), String.t()) :: :ok
  def delete_entry(owner, contact_nickname) do
    owner_lower = String.downcase(owner)
    contact_lower = String.downcase(contact_nickname)

    from(e in ContactEntry,
      where:
        fragment("lower(?)", e.owner_nickname) == ^owner_lower and
          fragment("lower(?)", e.contact_nickname) == ^contact_lower
    )
    |> Repo.delete_all()

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec valid_nickname?(String.t()) :: boolean()
  defp valid_nickname?(nickname) when is_binary(nickname) do
    trimmed = String.trim(nickname)
    byte_size(trimmed) > 0 and String.length(trimmed) <= @max_nickname_length
  end

  defp valid_nickname?(_), do: false
end
