defmodule RetroHexChat.Chat.Favorites do
  @moduledoc """
  Pure domain module for managing a user's channel favorites list.

  Provides in-memory CRUD operations on the favorites map structure.
  Persistence functions (save/2, load/1) require database access.
  """

  alias RetroHexChat.Chat.FavoriteEntry
  alias RetroHexChat.Chat.PasswordEncryption
  alias RetroHexChat.Chat.Schemas.FavoriteEntry, as: FavoriteEntrySchema
  alias RetroHexChat.Repo

  import Ecto.Query

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec entries(map()) :: [FavoriteEntry.t()]
  def entries(favorites) do
    Enum.sort_by(favorites.entries, & &1.position)
  end

  @spec add_entry(map(), map()) :: {:ok, map()} | {:error, :duplicate}
  def add_entry(favorites, attrs) do
    channel_name = Map.get(attrs, :channel_name) || Map.get(attrs, "channel_name")

    if has_entry?(favorites, channel_name) do
      {:error, :duplicate}
    else
      position = next_position(favorites)

      entry =
        FavoriteEntry.new(
          channel_name: channel_name,
          description: Map.get(attrs, :description, "") || "",
          password: Map.get(attrs, :password),
          auto_join: Map.get(attrs, :auto_join, false),
          position: position
        )

      {:ok, %{favorites | entries: favorites.entries ++ [entry]}}
    end
  end

  @spec update_entry(map(), String.t(), map()) :: {:ok, map()} | {:error, :not_found}
  def update_entry(favorites, channel_name, attrs) do
    downcased = String.downcase(channel_name)

    case find_and_update(favorites.entries, downcased, attrs) do
      {:ok, updated_entries} ->
        {:ok, %{favorites | entries: updated_entries}}

      :not_found ->
        {:error, :not_found}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(favorites, channel_name) do
    downcased = String.downcase(channel_name)

    case Enum.split_with(favorites.entries, fn e ->
           String.downcase(e.channel_name) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        {:ok, %{favorites | entries: reindex(rest)}}
    end
  end

  @spec find_entry(map(), String.t()) :: FavoriteEntry.t() | nil
  def find_entry(favorites, channel_name) do
    downcased = String.downcase(channel_name)
    Enum.find(favorites.entries, fn e -> String.downcase(e.channel_name) == downcased end)
  end

  @spec has_entry?(map(), String.t()) :: boolean()
  def has_entry?(favorites, channel_name) do
    find_entry(favorites, channel_name) != nil
  end

  @spec move_up(map(), String.t()) :: map()
  def move_up(favorites, channel_name) do
    sorted = entries(favorites)

    idx =
      Enum.find_index(sorted, fn e ->
        String.downcase(e.channel_name) == String.downcase(channel_name)
      end)

    if idx && idx > 0 do
      swapped =
        sorted
        |> List.replace_at(idx, Enum.at(sorted, idx - 1))
        |> List.replace_at(idx - 1, Enum.at(sorted, idx))

      %{favorites | entries: reindex(swapped)}
    else
      favorites
    end
  end

  @spec move_down(map(), String.t()) :: map()
  def move_down(favorites, channel_name) do
    sorted = entries(favorites)

    idx =
      Enum.find_index(sorted, fn e ->
        String.downcase(e.channel_name) == String.downcase(channel_name)
      end)

    if idx && idx < length(sorted) - 1 do
      swapped =
        sorted
        |> List.replace_at(idx, Enum.at(sorted, idx + 1))
        |> List.replace_at(idx + 1, Enum.at(sorted, idx))

      %{favorites | entries: reindex(swapped)}
    else
      favorites
    end
  end

  @spec auto_join_entries(map()) :: [FavoriteEntry.t()]
  def auto_join_entries(favorites) do
    favorites
    |> entries()
    |> Enum.filter(& &1.auto_join)
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, favorites) do
    Repo.transaction(fn ->
      from(e in FavoriteEntrySchema, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(favorites.entries, &insert_entry(owner, &1))
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    db_entries =
      from(e in FavoriteEntrySchema,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.position]
      )
      |> Repo.all()

    if db_entries == [] do
      {:error, :not_found}
    else
      {:ok, %{entries: Enum.map(db_entries, &to_domain_entry/1)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp next_position(favorites) do
    case favorites.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp reindex(entries) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} -> %{entry | position: idx} end)
  end

  defp find_and_update(entries, downcased_name, attrs) do
    case Enum.split_while(entries, fn e ->
           String.downcase(e.channel_name) != downcased_name
         end) do
      {_before, []} ->
        :not_found

      {before, [target | after_list]} ->
        updated =
          target
          |> maybe_update(:description, Map.get(attrs, :description))
          |> maybe_update(:password, Map.get(attrs, :password))
          |> maybe_update(:auto_join, Map.get(attrs, :auto_join))

        {:ok, before ++ [updated | after_list]}
    end
  end

  defp maybe_update(entry, _key, nil), do: entry
  defp maybe_update(entry, key, value), do: Map.put(entry, key, value)

  defp insert_entry(owner, entry) do
    encrypted_pw =
      if entry.password && entry.password != "" do
        PasswordEncryption.encrypt(entry.password)
      end

    %FavoriteEntrySchema{}
    |> FavoriteEntrySchema.changeset(%{
      owner_nickname: owner,
      channel_name: entry.channel_name,
      description: entry.description || "",
      encrypted_password: encrypted_pw,
      auto_join: entry.auto_join,
      position: entry.position
    })
    |> Repo.insert!()
  end

  defp to_domain_entry(db_entry) do
    password =
      case PasswordEncryption.decrypt(db_entry.encrypted_password) do
        {:ok, pw} -> pw
        :error -> nil
      end

    FavoriteEntry.new(
      channel_name: db_entry.channel_name,
      description: db_entry.description || "",
      password: password,
      auto_join: db_entry.auto_join,
      position: db_entry.position
    )
  end
end
