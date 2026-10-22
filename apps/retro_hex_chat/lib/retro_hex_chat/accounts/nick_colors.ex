defmodule RetroHexChat.Accounts.NickColors do
  @moduledoc """
  Pure domain module for managing a user's nick color overrides.

  Provides in-memory CRUD operations on the nick colors map structure,
  plus persistence functions that delegate to Ecto/Repo for database storage.
  """

  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query
  import RetroHexChat.Nickname, only: [matches: 2]

  alias RetroHexChat.Accounts.{NickColor, NickColorEntry}
  alias RetroHexChat.NicknameList
  alias RetroHexChat.OwnedList
  alias RetroHexChat.Repo

  @list NicknameList.new(field: :target_nickname, max_entries: 50)

  @irc_color_names %{
    0 => dgettext("accounts", "White"),
    1 => dgettext("accounts", "Black"),
    2 => dgettext("accounts", "Navy"),
    3 => dgettext("accounts", "Green"),
    4 => dgettext("accounts", "Red"),
    5 => dgettext("accounts", "Maroon"),
    6 => dgettext("accounts", "Purple"),
    7 => dgettext("accounts", "Orange"),
    8 => dgettext("accounts", "Yellow"),
    9 => dgettext("accounts", "Lime"),
    10 => dgettext("accounts", "Teal"),
    11 => dgettext("accounts", "Cyan"),
    12 => dgettext("accounts", "Blue"),
    13 => dgettext("accounts", "Magenta"),
    14 => dgettext("accounts", "Grey"),
    15 => dgettext("accounts", "Silver")
  }

  # ---------------------------------------------------------------------------
  # Color Lookup
  # ---------------------------------------------------------------------------

  @spec name_for_index(non_neg_integer()) :: String.t() | nil
  def name_for_index(index) do
    Map.get(@irc_color_names, index)
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

      NicknameList.member?(@list, nick_colors, target_nickname) ->
        {:error, :duplicate}

      full?(nick_colors) ->
        {:error, :list_full}

      true ->
        entry = NickColor.new(target_nickname: target_nickname, color_index: color_index)
        {:ok, %{nick_colors | entries: nick_colors.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(nick_colors, target_nickname),
    do: NicknameList.remove(@list, nick_colors, target_nickname)

  @spec update_color(map(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, :not_found | :invalid_color}
  def update_color(_nick_colors, _target_nickname, color_index) when not is_integer(color_index),
    do: {:error, :invalid_color}

  def update_color(_nick_colors, _target_nickname, color_index)
      when color_index < 0 or color_index > 15,
      do: {:error, :invalid_color}

  def update_color(nick_colors, target_nickname, color_index) do
    NicknameList.update(@list, nick_colors, target_nickname, &%{&1 | color_index: color_index})
  end

  @spec add_or_update(map(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, :list_full | :invalid_nickname | :invalid_color}
  def add_or_update(nick_colors, target_nickname, color_index) do
    if NicknameList.member?(@list, nick_colors, target_nickname) do
      update_color(nick_colors, target_nickname, color_index)
    else
      add_entry(nick_colors, target_nickname, color_index)
    end
  end

  @spec color_index_for(map(), String.t()) :: non_neg_integer() | nil
  def color_index_for(nick_colors, nickname) do
    case NicknameList.find(@list, nick_colors, nickname) do
      nil -> nil
      entry -> entry.color_index
    end
  end

  @spec sorted_entries(map()) :: [NickColor.t()]
  def sorted_entries(nick_colors), do: NicknameList.sorted(@list, nick_colors.entries)

  @spec count(map()) :: non_neg_integer()
  def count(nick_colors) do
    length(nick_colors.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(nick_colors), do: NicknameList.full?(@list, nick_colors)

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, nick_colors) do
    OwnedList.replace(NickColorEntry, owner, nick_colors.entries, fn entry ->
      %{target_nickname: entry.target_nickname, color_index: entry.color_index}
    end)
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    OwnedList.load(
      NickColorEntry,
      owner,
      &NickColor.new(target_nickname: &1.target_nickname, color_index: &1.color_index)
    )
  end

  @spec save_entry(String.t(), NickColor.t()) :: :ok | {:error, term()}
  def save_entry(owner, entry) do
    existing =
      from(e in NickColorEntry,
        where:
          matches(e.owner_nickname, owner) and matches(e.target_nickname, entry.target_nickname)
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
    from(e in NickColorEntry,
      where: matches(e.owner_nickname, owner) and matches(e.target_nickname, target_nickname)
    )
    |> Repo.delete_all()

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec valid_nickname?(String.t()) :: boolean()
  defp valid_nickname?(nickname) do
    is_binary(nickname) and byte_size(nickname) > 0 and String.length(nickname) <= 16
  end

  @spec valid_color?(non_neg_integer()) :: boolean()
  defp valid_color?(color_index) do
    is_integer(color_index) and color_index >= 0 and color_index <= 15
  end
end
