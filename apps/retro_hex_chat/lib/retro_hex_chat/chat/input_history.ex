defmodule RetroHexChat.Chat.InputHistory do
  @moduledoc """
  Composer input history for registered users.

  The browser keeps a per-page in-memory cache for keyboard navigation, but this
  module owns the durable version and repeats the sensitive-command filtering on
  the server side.
  """

  alias RetroHexChat.Chat.Schemas.InputHistory, as: InputHistorySchema
  alias RetroHexChat.Repo

  @type t :: %{
          entries: [String.t()],
          recent_commands: [String.t()]
        }

  @max_entries 100
  @max_recent_commands 5
  @max_entry_length 1000
  @max_command_length 64

  @sensitive_patterns [
    ~r/^\/identify(?:\s|$)/i,
    ~r/^\/nickserv(?:\s|$)/i,
    ~r/^\/ns(?:\s|$)/i,
    ~r/^\/(?:msg|query|notice)\s+nickserv\s+identify(?:\s|$)/i,
    ~r/^\/perform\s+add\s+\/(?:identify|nickserv|ns)(?:\s|$)/i,
    ~r/^\/alias\s+add\s+\S+\s+\/(?:identify|nickserv|ns)(?:\s|$)/i,
    ~r/^\/autorespond\s+add\s+\S+(?:\s+#\S+)?\s+\/(?:identify|nickserv|ns)(?:\s|$)/i,
    ~r/^\/timer\s+\S+\s+(?:repeat\s+)?\S+\s+\/(?:identify|nickserv|ns)(?:\s|$)/i
  ]

  @spec new() :: t()
  def new, do: %{entries: [], recent_commands: []}

  @spec from_lists(term(), term()) :: t()
  def from_lists(entries, recent_commands) do
    %{
      entries: normalize_entries(entries),
      recent_commands: normalize_recent_commands(recent_commands)
    }
  end

  @spec entries(map()) :: [String.t()]
  def entries(%{entries: entries}), do: normalize_entries(entries)
  def entries(_history), do: []

  @spec recent_commands(map()) :: [String.t()]
  def recent_commands(%{recent_commands: commands}), do: normalize_recent_commands(commands)
  def recent_commands(_history), do: []

  @spec record_submission(map(), term()) :: t()
  def record_submission(history, text) when is_binary(text) do
    normalized = from_lists(entries(history), recent_commands(history))
    submitted = String.trim_trailing(text)

    cond do
      String.trim(submitted) == "" ->
        normalized

      String.length(submitted) > @max_entry_length ->
        normalized

      sensitive_command?(submitted) ->
        normalized

      true ->
        %{
          entries: prepend_unique(submitted, normalized.entries, @max_entries),
          recent_commands: maybe_record_recent_command(normalized.recent_commands, submitted)
        }
    end
  end

  def record_submission(history, _text),
    do: from_lists(entries(history), recent_commands(history))

  @spec sensitive_command?(String.t()) :: boolean()
  def sensitive_command?(text) when is_binary(text) do
    trimmed = String.trim_leading(text)
    Enum.any?(@sensitive_patterns, &Regex.match?(&1, trimmed))
  end

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, history) do
    normalized = from_lists(entries(history), recent_commands(history))

    attrs = %{
      owner_nickname: owner,
      entries: normalized.entries,
      recent_commands: normalized.recent_commands
    }

    case Repo.get(InputHistorySchema, owner) do
      nil ->
        %InputHistorySchema{}
        |> InputHistorySchema.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> InputHistorySchema.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, t()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(InputHistorySchema, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok, from_lists(db_entry.entries, db_entry.recent_commands)}
    end
  end

  defp maybe_record_recent_command(recent_commands, "/" <> command_text) do
    case Regex.run(~r/^([a-z0-9_][a-z0-9_-]*)/i, command_text) do
      [_, command] ->
        command
        |> String.downcase()
        |> then(&prepend_unique(&1, recent_commands, @max_recent_commands))

      _ ->
        recent_commands
    end
  end

  defp maybe_record_recent_command(recent_commands, _text), do: recent_commands

  defp normalize_entries(entries) when is_list(entries) do
    entries
    |> Enum.filter(&valid_entry?/1)
    |> dedupe()
    |> Enum.take(@max_entries)
  end

  defp normalize_entries(_entries), do: []

  defp normalize_recent_commands(commands) when is_list(commands) do
    commands
    |> Enum.filter(&valid_command?/1)
    |> Enum.map(&String.downcase/1)
    |> dedupe()
    |> Enum.take(@max_recent_commands)
  end

  defp normalize_recent_commands(_commands), do: []

  defp valid_entry?(entry) when is_binary(entry) do
    String.trim(entry) != "" and String.length(entry) <= @max_entry_length
  end

  defp valid_entry?(_entry), do: false

  defp valid_command?(command) when is_binary(command) do
    String.trim(command) != "" and
      String.length(command) <= @max_command_length and
      Regex.match?(~r/^[a-z0-9_][a-z0-9_-]*$/i, command)
  end

  defp valid_command?(_command), do: false

  defp prepend_unique(value, values, limit) do
    [value | Enum.reject(values, &(&1 == value))]
    |> Enum.take(limit)
  end

  defp dedupe(values) do
    values
    |> Enum.reduce({MapSet.new(), []}, fn value, {seen, acc} ->
      if MapSet.member?(seen, value) do
        {seen, acc}
      else
        {MapSet.put(seen, value), [value | acc]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end
end
