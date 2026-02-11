defmodule RetroHexChat.Accounts.NickColors do
  @moduledoc """
  Pure domain module for managing a user's nick color overrides.

  Provides in-memory CRUD operations on the nick colors map structure,
  plus persistence functions that delegate to Ecto/Repo for database storage.
  """

  import Ecto.Query

  alias RetroHexChat.Accounts.{NickColor, NickColorEntry}
  alias RetroHexChat.Repo

  @max_entries 50

  @irc_colors %{
    0 => "#ffffff",
    1 => "#000000",
    2 => "#00007f",
    3 => "#009300",
    4 => "#ff0000",
    5 => "#7f0000",
    6 => "#9c009c",
    7 => "#fc7f00",
    8 => "#ffff00",
    9 => "#00fc00",
    10 => "#009393",
    11 => "#00ffff",
    12 => "#0000fc",
    13 => "#ff00ff",
    14 => "#7f7f7f",
    15 => "#d2d2d2"
  }

  # ---------------------------------------------------------------------------
  # Color Lookup
  # ---------------------------------------------------------------------------

  @spec hex_for_index(non_neg_integer()) :: String.t() | nil
  def hex_for_index(index) do
    Map.get(@irc_colors, index)
  end

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, :duplicate | :list_full | :invalid_nickname | :invalid_color}
  def add_entry(nick_colors, target_nickname, color_index) do
    cond do
      not valid_nickname?(target_nickname) ->
        {:error, :invalid_nickname}

      not valid_color?(color_index) ->
        {:error, :invalid_color}

      has_entry?(nick_colors, target_nickname) ->
        {:error, :duplicate}

      full?(nick_colors) ->
        {:error, :list_full}

      true ->
        entry = NickColor.new(target_nickname: target_nickname, color_index: color_index)
        {:ok, %{nick_colors | entries: nick_colors.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(nick_colors, target_nickname) do
    downcased = String.downcase(target_nickname)

    case Enum.split_with(nick_colors.entries, fn e ->
           String.downcase(e.target_nickname) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_found, remaining} ->
        {:ok, %{nick_colors | entries: remaining}}
    end
  end

  @spec update_color(map(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, :not_found | :invalid_color}
  def update_color(_nick_colors, _target_nickname, color_index) when not is_integer(color_index),
    do: {:error, :invalid_color}

  def update_color(_nick_colors, _target_nickname, color_index)
      when color_index < 0 or color_index > 15,
      do: {:error, :invalid_color}

  def update_color(nick_colors, target_nickname, color_index) do
    downcased = String.downcase(target_nickname)

    case find_and_update(nick_colors.entries, downcased, fn entry ->
           %{entry | color_index: color_index}
         end) do
      {:ok, updated_entries} ->
        {:ok, %{nick_colors | entries: updated_entries}}

      :not_found ->
        {:error, :not_found}
    end
  end

  @spec add_or_update(map(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, :list_full | :invalid_nickname | :invalid_color}
  def add_or_update(nick_colors, target_nickname, color_index) do
    if has_entry?(nick_colors, target_nickname) do
      update_color(nick_colors, target_nickname, color_index)
    else
      add_entry(nick_colors, target_nickname, color_index)
    end
  end

  @spec color_for(map(), String.t()) :: String.t() | nil
  def color_for(nick_colors, nickname) do
    downcased = String.downcase(nickname)

    case Enum.find(nick_colors.entries, fn e ->
           String.downcase(e.target_nickname) == downcased
         end) do
      nil -> nil
      entry -> hex_for_index(entry.color_index)
    end
  end

  @spec sorted_entries(map()) :: [NickColor.t()]
  def sorted_entries(nick_colors) do
    Enum.sort_by(nick_colors.entries, &String.downcase(&1.target_nickname))
  end

  @spec count(map()) :: non_neg_integer()
  def count(nick_colors) do
    length(nick_colors.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(nick_colors) do
    count(nick_colors) >= @max_entries
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, nick_colors) do
    Repo.transaction(fn ->
      from(e in NickColorEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(nick_colors.entries, fn entry ->
        %NickColorEntry{}
        |> NickColorEntry.changeset(%{
          owner_nickname: owner,
          target_nickname: entry.target_nickname,
          color_index: entry.color_index
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
      from(e in NickColorEntry, where: e.owner_nickname == ^owner)
      |> Repo.all()

    if entries == [] do
      {:error, :not_found}
    else
      nick_colors =
        Enum.map(entries, fn db_entry ->
          NickColor.new(
            target_nickname: db_entry.target_nickname,
            color_index: db_entry.color_index
          )
        end)

      {:ok, %{entries: nick_colors}}
    end
  end

  @spec save_entry(String.t(), NickColor.t()) :: :ok | {:error, term()}
  def save_entry(owner, entry) do
    owner_lower = String.downcase(owner)
    target_lower = String.downcase(entry.target_nickname)

    existing =
      from(e in NickColorEntry,
        where:
          fragment("lower(?)", e.owner_nickname) == ^owner_lower and
            fragment("lower(?)", e.target_nickname) == ^target_lower
      )
      |> Repo.one()

    changeset_attrs = %{
      owner_nickname: owner,
      target_nickname: entry.target_nickname,
      color_index: entry.color_index
    }

    result =
      if existing do
        existing
        |> NickColorEntry.changeset(changeset_attrs)
        |> Repo.update()
      else
        %NickColorEntry{}
        |> NickColorEntry.changeset(changeset_attrs)
        |> Repo.insert()
      end

    case result do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec delete_entry(String.t(), String.t()) :: :ok
  def delete_entry(owner, target_nickname) do
    owner_lower = String.downcase(owner)
    target_lower = String.downcase(target_nickname)

    from(e in NickColorEntry,
      where:
        fragment("lower(?)", e.owner_nickname) == ^owner_lower and
          fragment("lower(?)", e.target_nickname) == ^target_lower
    )
    |> Repo.delete_all()

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec has_entry?(map(), String.t()) :: boolean()
  defp has_entry?(nick_colors, target_nickname) do
    downcased = String.downcase(target_nickname)

    Enum.any?(nick_colors.entries, fn e ->
      String.downcase(e.target_nickname) == downcased
    end)
  end

  @spec valid_nickname?(String.t()) :: boolean()
  defp valid_nickname?(nickname) do
    is_binary(nickname) and byte_size(nickname) > 0 and String.length(nickname) <= 16
  end

  @spec valid_color?(non_neg_integer()) :: boolean()
  defp valid_color?(color_index) do
    is_integer(color_index) and color_index >= 0 and color_index <= 15
  end

  @spec find_and_update([NickColor.t()], String.t(), (NickColor.t() -> NickColor.t())) ::
          {:ok, [NickColor.t()]} | :not_found
  defp find_and_update(entries, downcased_nick, update_fn) do
    {found, updated} =
      Enum.reduce(entries, {false, []}, fn entry, {found?, acc} ->
        if String.downcase(entry.target_nickname) == downcased_nick do
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
end
