defmodule RetroHexChat.Chat.AutoRespondRules do
  @moduledoc """
  Pure domain module for managing a user's auto-respond rules.

  Provides in-memory CRUD operations on the rules map structure.
  Persistence functions (save/2, load/1) require database access.
  """

  alias RetroHexChat.Chat.AliasExpander
  alias RetroHexChat.Chat.AutoRespondRule
  alias RetroHexChat.Chat.Schemas.AutoRespondRule, as: AutoRespondRuleSchema
  alias RetroHexChat.Repo

  import Ecto.Query

  @max_entries 10
  @max_command_length 500
  @valid_triggers [:on_join, :on_part, :on_nick_change]

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), atom(), String.t() | nil, String.t()) ::
          {:ok, map()} | {:error, atom()}
  def add_entry(rules, trigger_event, channel_filter, command) do
    trimmed_cmd = String.trim(command)
    trimmed_filter = if channel_filter, do: String.trim(channel_filter), else: nil

    with :ok <- validate_add(rules, trigger_event, trimmed_filter, trimmed_cmd) do
      build_and_add(rules, trigger_event, trimmed_filter, trimmed_cmd)
    end
  end

  defp validate_add(rules, trigger_event, trimmed_filter, trimmed_cmd) do
    cond do
      full?(rules) -> {:error, :list_full}
      trigger_event not in @valid_triggers -> {:error, :invalid_trigger}
      trimmed_filter != nil and not valid_channel?(trimmed_filter) -> {:error, :invalid_channel}
      String.length(trimmed_cmd) > @max_command_length -> {:error, :command_too_long}
      AliasExpander.contains_chaining?(trimmed_cmd) -> {:error, :command_chaining}
      true -> :ok
    end
  end

  defp build_and_add(rules, trigger_event, trimmed_filter, trimmed_cmd) do
    position = next_position(rules)
    id = next_id(rules)

    entry =
      AutoRespondRule.new(
        id: id,
        trigger_event: trigger_event,
        channel_filter: if(trimmed_filter == "", do: nil, else: trimmed_filter),
        command: trimmed_cmd,
        position: position
      )

    {:ok, %{rules | entries: rules.entries ++ [entry]}}
  end

  @spec remove_entry(map(), non_neg_integer()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(rules, position) do
    case Enum.split_with(rules.entries, &(&1.position == position)) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        {:ok, %{rules | entries: reindex(rest)}}
    end
  end

  @spec update_entry(map(), non_neg_integer(), map()) ::
          {:ok, map()} | {:error, atom()}
  def update_entry(rules, position, attrs) do
    if find_by_position(rules, position) == nil do
      {:error, :not_found}
    else
      do_update_entry(rules, position, attrs)
    end
  end

  defp do_update_entry(rules, position, attrs) do
    new_cmd = Map.get(attrs, :command)

    if new_cmd != nil and AliasExpander.contains_chaining?(new_cmd) do
      {:error, :command_chaining}
    else
      updated = Enum.map(rules.entries, &apply_update(&1, position, attrs))
      {:ok, %{rules | entries: updated}}
    end
  end

  defp apply_update(entry, position, attrs) when entry.position == position do
    entry
    |> maybe_update(:trigger_event, attrs)
    |> maybe_update(:channel_filter, attrs)
    |> maybe_update(:command, attrs)
    |> maybe_update(:enabled, attrs)
  end

  defp apply_update(entry, _position, _attrs), do: entry

  @spec toggle_entry(map(), non_neg_integer()) :: {:ok, map()} | {:error, :not_found}
  def toggle_entry(rules, position) do
    if find_by_position(rules, position) == nil do
      {:error, :not_found}
    else
      updated = Enum.map(rules.entries, &toggle_if_match(&1, position))
      {:ok, %{rules | entries: updated}}
    end
  end

  defp toggle_if_match(entry, position) when entry.position == position do
    %{entry | enabled: not entry.enabled}
  end

  defp toggle_if_match(entry, _position), do: entry

  @spec matching_rules(map(), atom(), String.t() | nil) :: [AutoRespondRule.t()]
  def matching_rules(rules, event_type, channel) do
    rules.entries
    |> Enum.filter(fn entry ->
      entry.enabled and
        entry.trigger_event == event_type and
        channel_matches?(entry.channel_filter, channel)
    end)
  end

  @spec entries(map()) :: [AutoRespondRule.t()]
  def entries(rules) do
    Enum.sort_by(rules.entries, & &1.position)
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, rules) do
    Repo.transaction(fn ->
      from(e in AutoRespondRuleSchema, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(rules.entries, fn entry ->
        %AutoRespondRuleSchema{}
        |> AutoRespondRuleSchema.changeset(%{
          owner_nickname: owner,
          trigger_event: Atom.to_string(entry.trigger_event),
          channel_filter: entry.channel_filter,
          command: entry.command,
          enabled: entry.enabled,
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
      from(e in AutoRespondRuleSchema,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.position]
      )
      |> Repo.all()

    if entries == [] do
      {:error, :not_found}
    else
      domain_entries =
        Enum.with_index(entries)
        |> Enum.map(fn {db_entry, idx} ->
          AutoRespondRule.new(
            id: idx,
            trigger_event: String.to_existing_atom(db_entry.trigger_event),
            channel_filter: db_entry.channel_filter,
            command: db_entry.command,
            enabled: db_entry.enabled,
            position: db_entry.position
          )
        end)

      {:ok, %{entries: domain_entries}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp full?(rules) do
    length(rules.entries) >= @max_entries
  end

  defp valid_channel?(filter) do
    String.starts_with?(filter, "#")
  end

  defp find_by_position(rules, position) do
    Enum.find(rules.entries, &(&1.position == position))
  end

  defp next_position(rules) do
    case rules.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp next_id(rules) do
    case rules.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.id) |> Enum.max()) + 1
    end
  end

  defp reindex(entries) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} -> %{entry | position: idx} end)
  end

  defp channel_matches?(nil, _channel), do: true

  defp channel_matches?(filter, channel) when is_binary(filter) and is_binary(channel) do
    String.downcase(filter) == String.downcase(channel)
  end

  defp channel_matches?(_filter, _channel), do: false

  defp maybe_update(entry, key, attrs) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> Map.put(entry, key, value)
      :error -> entry
    end
  end
end
