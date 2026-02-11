defmodule RetroHexChat.Chat.HighlightWords do
  @moduledoc """
  Pure domain module for managing a user's highlight word list.

  Provides in-memory CRUD operations on the highlight words map structure.
  Persistence functions are added in Phase 6 (US5).
  """

  import Ecto.Query

  alias RetroHexChat.Accounts.HighlightWordEntry
  alias RetroHexChat.Chat.HighlightWord
  alias RetroHexChat.Repo

  @max_entries 50

  @spec new() :: map()
  def new do
    %{entries: []}
  end

  @spec add_entry(map(), String.t(), non_neg_integer() | nil) ::
          {:ok, map()} | {:error, :invalid_word | :duplicate | :list_full | :invalid_color}
  def add_entry(highlight_words, word, bg_color) do
    trimmed = String.trim(word)

    cond do
      not valid_word?(trimmed) ->
        {:error, :invalid_word}

      bg_color != nil and not valid_color?(bg_color) ->
        {:error, :invalid_color}

      has_entry?(highlight_words, trimmed) ->
        {:error, :duplicate}

      full?(highlight_words) ->
        {:error, :list_full}

      true ->
        position = next_position(highlight_words)
        entry = HighlightWord.new(word: trimmed, bg_color: bg_color, position: position)
        {:ok, %{highlight_words | entries: highlight_words.entries ++ [entry]}}
    end
  end

  @spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def remove_entry(highlight_words, word) do
    downcased = String.downcase(word)

    case Enum.split_with(highlight_words.entries, fn e ->
           String.downcase(e.word) == downcased
         end) do
      {[], _rest} ->
        {:error, :not_found}

      {_removed, rest} ->
        {:ok, %{highlight_words | entries: rest}}
    end
  end

  @spec update_entry(map(), String.t(), non_neg_integer() | nil) ::
          {:ok, map()} | {:error, :not_found | :invalid_color}
  def update_entry(highlight_words, word, bg_color) do
    if bg_color != nil and not valid_color?(bg_color) do
      {:error, :invalid_color}
    else
      downcased = String.downcase(word)

      case find_and_update(highlight_words.entries, downcased, bg_color) do
        {:ok, updated_entries} ->
          {:ok, %{highlight_words | entries: updated_entries}}

        :not_found ->
          {:error, :not_found}
      end
    end
  end

  @spec entries(map()) :: [HighlightWord.t()]
  def entries(highlight_words) do
    Enum.sort_by(highlight_words.entries, & &1.position)
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, highlight_words) do
    Repo.transaction(fn ->
      from(e in HighlightWordEntry, where: e.owner_nickname == ^owner)
      |> Repo.delete_all()

      highlight_words.entries
      |> Enum.with_index()
      |> Enum.each(fn {entry, idx} ->
        %HighlightWordEntry{}
        |> HighlightWordEntry.changeset(%{
          owner_nickname: owner,
          word: entry.word,
          bg_color: entry.bg_color,
          position: idx
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
      from(e in HighlightWordEntry,
        where: e.owner_nickname == ^owner,
        order_by: [asc: e.position]
      )
      |> Repo.all()

    if entries == [] do
      {:error, :not_found}
    else
      words =
        Enum.map(entries, fn db_entry ->
          HighlightWord.new(
            word: db_entry.word,
            bg_color: db_entry.bg_color,
            position: db_entry.position
          )
        end)

      {:ok, %{entries: words}}
    end
  end

  # Private helpers

  defp valid_word?(word), do: word != "" and String.length(word) <= 50

  defp valid_color?(index) when is_integer(index), do: index >= 0 and index <= 15
  defp valid_color?(_), do: false

  defp has_entry?(highlight_words, word) do
    downcased = String.downcase(word)
    Enum.any?(highlight_words.entries, fn e -> String.downcase(e.word) == downcased end)
  end

  defp full?(highlight_words), do: length(highlight_words.entries) >= @max_entries

  defp next_position(highlight_words) do
    case highlight_words.entries do
      [] -> 0
      entries -> (entries |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp find_and_update(entries, downcased_word, bg_color) do
    case Enum.split_while(entries, fn e -> String.downcase(e.word) != downcased_word end) do
      {_before, []} ->
        :not_found

      {before, [target | after_list]} ->
        updated = %{target | bg_color: bg_color}
        {:ok, before ++ [updated | after_list]}
    end
  end
end
