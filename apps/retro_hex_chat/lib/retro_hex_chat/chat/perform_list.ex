defmodule RetroHexChat.Chat.PerformList do
  @moduledoc """
  Pure domain module for managing a user's perform command list.

  Provides in-memory CRUD operations on the perform list map structure.
  Persistence functions (save/2, load/1) require database access.
  """

  alias RetroHexChat.Chat.PerformEntry
  alias RetroHexChat.Chat.Schemas.PerformListEntry
  alias RetroHexChat.Chat.Schemas.PerformSettings
  alias RetroHexChat.Repo

  import Ecto.Query

  @max_entries 50
  @max_command_length 500
  @disallowed_commands ~w(quit perform autojoin disconnect)

  @spec new() :: map()
  def new do
    %{entries: [], settings: %{enable_on_connect: true}}
  end

  @spec add_entry(map(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def add_entry(perform_list, command) do
    trimmed = String.trim(command)

    cond do
      full?(perform_list) ->
        {:error, :list_full}

      not valid_command?(trimmed) ->
        {:error, :invalid_command}

      disallowed_command?(trimmed) ->
        {:error, :disallowed_command}

      String.length(trimmed) > @max_command_length ->
        {:error, :command_too_long}

      true ->
        position = next_position(perform_list)
        entry = PerformEntry.new(command: trimmed, position: position)
        {:ok, %{perform_list | entries: perform_list.entries ++ [entry]}}
    end
  end

  @spec update_entry(map(), non_neg_integer(), String.t()) :: map()
  def update_entry(perform_list, position, command) do
    updated =
      Enum.map(perform_list.entries, fn entry ->
        if entry.position == position, do: %{entry | command: command}, else: entry
      end)

    %{perform_list | entries: updated}
  end

  @spec remove_entry(map(), non_neg_integer()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(perform_list, position) do
    case Enum.split_with(perform_list.entries, &(&1.position == position)) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        reindexed = reindex(rest)
        {:ok, %{perform_list | entries: reindexed}}
    end
  end

  @spec move_entry(map(), non_neg_integer(), non_neg_integer()) ::
          {:ok, map()} | {:error, atom()}
  def move_entry(perform_list, from, to) do
    max_pos = length(perform_list.entries) - 1

    cond do
      from == to ->
        {:error, :same_position}

      from < 0 or from > max_pos or to < 0 or to > max_pos ->
        {:error, :invalid_position}

      true ->
        sorted = entries(perform_list)
        entry = Enum.at(sorted, from)
        remaining = List.delete_at(sorted, from)
        moved = List.insert_at(remaining, to, entry)
        {:ok, %{perform_list | entries: reindex(moved)}}
    end
  end

  @spec clear(map()) :: {:ok, map()}
  def clear(perform_list) do
    {:ok, %{perform_list | entries: []}}
  end

  @spec entries(map()) :: [PerformEntry.t()]
  def entries(perform_list) do
    Enum.sort_by(perform_list.entries, & &1.position)
  end

  @spec count(map()) :: non_neg_integer()
  def count(perform_list) do
    length(perform_list.entries)
  end

  @spec full?(map()) :: boolean()
  def full?(perform_list) do
    count(perform_list) >= @max_entries
  end

  @spec enabled?(map()) :: boolean()
  def enabled?(perform_list) do
    perform_list.settings.enable_on_connect
  end

  @spec set_enabled(map(), boolean()) :: map()
  def set_enabled(perform_list, value) when is_boolean(value) do
    put_in(perform_list, [:settings, :enable_on_connect], value)
  end

  # ---------------------------------------------------------------------------
  # Password Masking
  # ---------------------------------------------------------------------------

  @spec mask_command(String.t()) :: String.t()
  def mask_command(command) do
    command
    |> mask_ns_identify()
    |> mask_msg_nickserv_identify()
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  @spec disallowed_command?(String.t()) :: boolean()
  def disallowed_command?(command) do
    case extract_command_name(command) do
      nil -> false
      name -> String.downcase(name) in @disallowed_commands
    end
  end

  @spec valid_command?(String.t()) :: boolean()
  def valid_command?(command) do
    String.starts_with?(command, "/") and String.length(command) >= 2
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, perform_list) do
    Repo.transaction(fn ->
      from(e in PerformListEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(perform_list.entries, fn entry ->
        %PerformListEntry{}
        |> PerformListEntry.changeset(%{
          owner_nickname: owner,
          command: entry.command,
          position: entry.position
        })
        |> Repo.insert!()
      end)

      save_settings(owner, perform_list.settings)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    entries =
      from(e in PerformListEntry,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.position]
      )
      |> Repo.all()

    settings = load_settings(owner)

    if entries == [] and settings == nil do
      {:error, :not_found}
    else
      domain_entries =
        Enum.map(entries, fn db_entry ->
          PerformEntry.new(command: db_entry.command, position: db_entry.position)
        end)

      enable = if settings, do: settings.enable_on_connect, else: true

      {:ok, %{entries: domain_entries, settings: %{enable_on_connect: enable}}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp save_settings(owner, settings) do
    case Repo.get(PerformSettings, owner) do
      nil ->
        %PerformSettings{}
        |> PerformSettings.changeset(%{
          owner_nickname: owner,
          enable_on_connect: settings.enable_on_connect
        })
        |> Repo.insert!()

      existing ->
        existing
        |> PerformSettings.changeset(%{enable_on_connect: settings.enable_on_connect})
        |> Repo.update!()
    end
  end

  defp load_settings(owner) do
    Repo.get(PerformSettings, owner)
  end

  defp next_position(perform_list) do
    case perform_list.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp reindex(entries) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} -> %{entry | position: idx} end)
  end

  defp extract_command_name(command) do
    case String.split(command, " ", parts: 2) do
      [cmd | _] when cmd != "" -> String.trim_leading(cmd, "/")
      _ -> nil
    end
  end

  defp mask_ns_identify(command) do
    Regex.replace(~r{^(/ns\s+identify\s+)\S+(.*)$}i, command, "\\1****\\2")
  end

  defp mask_msg_nickserv_identify(command) do
    Regex.replace(
      ~r{^(/msg\s+nickserv\s+identify\s+)\S+(.*)$}i,
      command,
      "\\1****\\2"
    )
  end
end
