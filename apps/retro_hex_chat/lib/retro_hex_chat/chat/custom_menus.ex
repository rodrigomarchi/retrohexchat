defmodule RetroHexChat.Chat.CustomMenus do
  @moduledoc """
  Pure domain module for managing custom context menu items.
  Items can be added to nicklist, channel, or chat context menus.
  """

  alias RetroHexChat.Chat.{AliasExpander, CustomMenuItem, Positions}
  alias RetroHexChat.Chat.Schemas.CustomMenuItem, as: CustomMenuItemSchema
  alias RetroHexChat.OwnedList

  @max_per_type 10
  @max_label_length 50
  @max_command_length 500

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), :nicklist | :channel | :chat, String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def add_entry(menus, menu_type, label, command) do
    trimmed_label = String.trim(label)
    trimmed_command = String.trim(command)

    cond do
      not valid_label?(trimmed_label) ->
        {:error, :invalid_label}

      type_full?(menus, menu_type) ->
        {:error, :menu_full}

      has_entry?(menus, menu_type, trimmed_label) ->
        {:error, :duplicate_label}

      trimmed_command == "" ->
        {:error, :invalid_command}

      String.length(trimmed_command) > @max_command_length ->
        {:error, :command_too_long}

      AliasExpander.contains_chaining?(trimmed_command) ->
        {:error, :command_chaining}

      true ->
        position = Positions.next(menus.entries)

        entry =
          CustomMenuItem.new(
            menu_type: menu_type,
            label: trimmed_label,
            command: trimmed_command,
            position: position
          )

        {:ok, %{menus | entries: menus.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), :nicklist | :channel | :chat, String.t()) ::
          {:ok, map()} | {:error, :not_found}
  def remove_entry(menus, menu_type, label) do
    downcased = String.downcase(label)

    case Enum.split_with(menus.entries, fn e ->
           e.menu_type == menu_type and String.downcase(e.label) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        {:ok, %{menus | entries: Positions.renumber(rest)}}
    end
  end

  @spec update_entry(map(), :nicklist | :channel | :chat, String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def update_entry(menus, menu_type, old_label, new_label, new_command) do
    trimmed_label = String.trim(new_label)
    trimmed_command = String.trim(new_command)
    downcased = old_label |> String.trim() |> String.downcase()

    with {:ok, idx} <- find_entry_index(menus, menu_type, downcased),
         :ok <- validate_update(menus, menu_type, trimmed_label, trimmed_command, downcased) do
      updated =
        List.update_at(menus.entries, idx, fn entry ->
          %{entry | label: trimmed_label, command: trimmed_command}
        end)

      {:ok, %{menus | entries: updated}}
    end
  end

  @spec entries_for(map(), :nicklist | :channel | :chat) :: [CustomMenuItem.t()]
  def entries_for(menus, menu_type) do
    menus.entries
    |> Enum.filter(&(&1.menu_type == menu_type))
    |> Positions.in_order()
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, menus) do
    OwnedList.replace(CustomMenuItemSchema, owner, menus.entries, fn entry ->
      %{
        menu_type: Atom.to_string(entry.menu_type),
        label: entry.label,
        command: entry.command,
        position: entry.position
      }
    end)
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    OwnedList.load(
      CustomMenuItemSchema,
      owner,
      &CustomMenuItem.new(
        menu_type: String.to_existing_atom(&1.menu_type),
        label: &1.label,
        command: &1.command,
        position: &1.position
      ),
      order_by: :position
    )
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp valid_label?(label) do
    label != "" and String.length(label) <= @max_label_length
  end

  defp type_full?(menus, menu_type) do
    length(entries_for(menus, menu_type)) >= @max_per_type
  end

  defp find_entry_index(menus, menu_type, downcased_label) do
    case Enum.find_index(menus.entries, fn e ->
           e.menu_type == menu_type and String.downcase(e.label) == downcased_label
         end) do
      nil -> {:error, :not_found}
      idx -> {:ok, idx}
    end
  end

  defp validate_update(menus, menu_type, label, command, except_downcased_label) do
    cond do
      not valid_label?(label) ->
        {:error, :invalid_label}

      has_entry?(menus, menu_type, label, except_downcased_label) ->
        {:error, :duplicate_label}

      command == "" ->
        {:error, :invalid_command}

      String.length(command) > @max_command_length ->
        {:error, :command_too_long}

      AliasExpander.contains_chaining?(command) ->
        {:error, :command_chaining}

      true ->
        :ok
    end
  end

  defp has_entry?(menus, menu_type, label, except_downcased_label \\ nil) do
    downcased = String.downcase(label)

    Enum.any?(menus.entries, fn e ->
      entry_label = String.downcase(e.label)

      e.menu_type == menu_type and entry_label == downcased and
        entry_label != except_downcased_label
    end)
  end
end
