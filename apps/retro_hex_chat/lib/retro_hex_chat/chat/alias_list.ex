defmodule RetroHexChat.Chat.AliasList do
  @moduledoc """
  Pure domain module for managing a user's command alias list.

  Provides in-memory CRUD operations on the alias list map structure.
  Persistence functions (save/2, load/1) require database access.
  """

  alias RetroHexChat.Chat.AliasEntry
  alias RetroHexChat.Chat.AliasExpander
  alias RetroHexChat.Chat.Positions
  alias RetroHexChat.Chat.Schemas.AliasEntry, as: AliasEntrySchema
  alias RetroHexChat.Commands.Registry
  alias RetroHexChat.OwnedList

  @max_entries 50
  @max_expansion_length 500
  @max_name_length 30
  @name_pattern ~r/^[a-zA-Z0-9_-]+$/
  @expansion_command_pattern ~r/^\s*\/([a-zA-Z0-9_-]+)(?:\s|$)/

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def add_entry(alias_list, name, expansion) do
    trimmed_name = String.trim(name)
    trimmed_expansion = String.trim(expansion)

    cond do
      full?(alias_list) ->
        {:error, :list_full}

      not valid_name?(trimmed_name) ->
        {:error, :invalid_name}

      has_entry?(alias_list, trimmed_name) ->
        {:error, :duplicate_name}

      trimmed_expansion == "" ->
        {:error, :invalid_expansion}

      String.length(trimmed_expansion) > @max_expansion_length ->
        {:error, :expansion_too_long}

      AliasExpander.contains_chaining?(trimmed_expansion) ->
        {:error, :command_chaining}

      true ->
        position = Positions.next(alias_list.entries)

        entry =
          AliasEntry.new(name: trimmed_name, expansion: trimmed_expansion, position: position)

        {:ok, %{alias_list | entries: alias_list.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(alias_list, name) do
    downcased = String.downcase(name)

    case Enum.split_with(alias_list.entries, &(String.downcase(&1.name) == downcased)) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        {:ok, %{alias_list | entries: Positions.renumber(rest)}}
    end
  end

  @spec update_entry(map(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def update_entry(alias_list, name, new_expansion) do
    trimmed = String.trim(new_expansion)
    downcased = String.downcase(name)

    cond do
      not has_entry?(alias_list, name) ->
        {:error, :not_found}

      trimmed == "" ->
        {:error, :invalid_expansion}

      String.length(trimmed) > @max_expansion_length ->
        {:error, :expansion_too_long}

      AliasExpander.contains_chaining?(trimmed) ->
        {:error, :command_chaining}

      true ->
        updated = Enum.map(alias_list.entries, &update_if_match(&1, downcased, trimmed))
        {:ok, %{alias_list | entries: updated}}
    end
  end

  @spec find_entry(map(), String.t()) :: AliasEntry.t() | nil
  def find_entry(alias_list, name) do
    downcased = String.downcase(name)
    Enum.find(alias_list.entries, &(String.downcase(&1.name) == downcased))
  end

  @spec entries(map()) :: [AliasEntry.t()]
  def entries(alias_list) do
    Positions.in_order(alias_list.entries)
  end

  @spec shadows_builtin?(String.t()) :: boolean()
  def shadows_builtin?(name) do
    Registry.known?(String.downcase(name))
  end

  @spec recursive_expansion?(String.t(), String.t()) :: boolean()
  def recursive_expansion?(name, expansion) do
    downcased_name = name |> String.trim() |> String.downcase()

    case Regex.run(@expansion_command_pattern, expansion) do
      [_, command] -> String.downcase(command) == downcased_name
      _ -> false
    end
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, alias_list) do
    OwnedList.replace(AliasEntrySchema, owner, alias_list.entries, fn entry ->
      %{name: entry.name, expansion: entry.expansion, position: entry.position}
    end)
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    OwnedList.load(
      AliasEntrySchema,
      owner,
      &AliasEntry.new(name: &1.name, expansion: &1.expansion, position: &1.position),
      order_by: :position
    )
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp full?(alias_list) do
    length(alias_list.entries) >= @max_entries
  end

  defp valid_name?(name) do
    name != "" and
      String.length(name) <= @max_name_length and
      Regex.match?(@name_pattern, name)
  end

  defp has_entry?(alias_list, name) do
    find_entry(alias_list, name) != nil
  end

  defp update_if_match(entry, downcased_name, new_expansion) do
    if String.downcase(entry.name) == downcased_name do
      %{entry | expansion: new_expansion}
    else
      entry
    end
  end
end
