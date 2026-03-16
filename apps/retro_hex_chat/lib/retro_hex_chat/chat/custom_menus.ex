defmodule RetroHexChat.Chat.CustomMenus do
  @moduledoc """
  Pure domain module for managing custom context menu items.
  Items can be added to nicklist, channel, or chat context menus.
  """

  alias RetroHexChat.Chat.CustomMenuItem
  alias RetroHexChat.Chat.Schemas.CustomMenuItem, as: CustomMenuItemSchema
  alias RetroHexChat.Repo

  import Ecto.Query

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

      String.length(trimmed_command) > @max_command_length ->
        {:error, :command_too_long}

      true ->
        position = next_position(menus)

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
        {:ok, %{menus | entries: reindex(rest)}}
    end
  end

  @spec update_entry(map(), :nicklist | :channel | :chat, String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def update_entry(menus, menu_type, old_label, new_label, new_command) do
    downcased = String.downcase(old_label)

    case Enum.find_index(menus.entries, fn e ->
           e.menu_type == menu_type and String.downcase(e.label) == downcased
         end) do
      nil ->
        {:error, :not_found}

      idx ->
        updated =
          List.update_at(menus.entries, idx, fn entry ->
            %{entry | label: String.trim(new_label), command: String.trim(new_command)}
          end)

        {:ok, %{menus | entries: updated}}
    end
  end

  @spec entries_for(map(), :nicklist | :channel | :chat) :: [CustomMenuItem.t()]
  def entries_for(menus, menu_type) do
    menus.entries
    |> Enum.filter(&(&1.menu_type == menu_type))
    |> Enum.sort_by(& &1.position)
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, menus) do
    Repo.transaction(fn ->
      from(e in CustomMenuItemSchema, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(menus.entries, fn entry ->
        %CustomMenuItemSchema{}
        |> CustomMenuItemSchema.changeset(%{
          owner_nickname: owner,
          menu_type: Atom.to_string(entry.menu_type),
          label: entry.label,
          command: entry.command,
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
      from(e in CustomMenuItemSchema,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.position]
      )
      |> Repo.all()

    if entries == [] do
      {:error, :not_found}
    else
      domain_entries =
        Enum.map(entries, fn db_entry ->
          CustomMenuItem.new(
            menu_type: String.to_existing_atom(db_entry.menu_type),
            label: db_entry.label,
            command: db_entry.command,
            position: db_entry.position
          )
        end)

      {:ok, %{entries: domain_entries}}
    end
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

  defp has_entry?(menus, menu_type, label) do
    downcased = String.downcase(label)

    Enum.any?(menus.entries, fn e ->
      e.menu_type == menu_type and String.downcase(e.label) == downcased
    end)
  end

  defp next_position(menus) do
    case menus.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp reindex(entries) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} -> %{entry | position: idx} end)
  end
end
