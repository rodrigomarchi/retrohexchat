defmodule RetroHexChat.OwnedList do
  @moduledoc """
  The rows one person's list occupies: written whole, read back whole.

  A dozen tables here hold the same thing — a list that belongs to one
  nickname. Aliases, autojoin channels, perform commands, custom menu items,
  auto-respond rules, highlight words, ignored people, contacts, nick colours,
  notify entries. Each is edited entirely in memory and only then written, so
  saving one means replacing every row that person owns rather than working out
  which changed.

  That replacement happens in a transaction. Deleting first and inserting after
  is only safe as one step: a reader arriving between them would find the list
  empty, and a failed insert would otherwise leave it that way for good.

  A row is inserted with `Repo.insert!/1`, so a value the column refuses aborts
  the whole write instead of silently dropping one entry from a list the person
  believes they saved. What each caller supplies is the shape: which table,
  what a row looks like for an entry, and what an entry looks like for a row.
  """

  import Ecto.Query

  alias RetroHexChat.Repo

  @doc """
  Replaces every row `owner` has in `schema` with `entries`.

  `to_attrs` describes one row without the owner, which is filled in here so no
  caller repeats it. `:then` runs inside the same transaction, for a list that
  keeps settings alongside its entries.
  """
  @spec replace(module(), String.t(), [struct()], (struct() -> map()), keyword()) ::
          :ok | {:error, term()}
  def replace(schema, owner, entries, to_attrs, opts \\ []) do
    Repo.transaction(fn ->
      schema
      |> where([row], row.owner_nickname == ^owner)
      |> Repo.delete_all()

      Enum.each(entries, fn entry ->
        schema
        |> struct()
        |> schema.changeset(Map.put(to_attrs.(entry), :owner_nickname, owner))
        |> Repo.insert!()
      end)

      case Keyword.get(opts, :then) do
        nil -> :ok
        also when is_function(also, 0) -> also.()
      end
    end)
    |> case do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  The entries `owner` has in `schema`, as the domain sees them.

  `:order_by` names the column that carries the order the person chose;
  `:keep` drops rows the domain no longer counts, such as an ignore that has
  run out.
  """
  @spec rows(module(), String.t(), (struct() -> struct()), keyword()) :: [struct()]
  def rows(schema, owner, to_entry, opts \\ []) do
    schema
    |> where([row], row.owner_nickname == ^owner)
    |> ordered(Keyword.get(opts, :order_by))
    |> Repo.all()
    |> kept(Keyword.get(opts, :keep))
    |> Enum.map(to_entry)
  end

  @doc """
  The list `owner` has in `schema`, or `:not_found` if they have none.

  `:not_found` rather than an empty list, because a person who has never saved
  one is different from a person who saved an empty one — the first gets
  whatever default the caller starts people with.
  """
  @spec load(module(), String.t(), (struct() -> struct()), keyword()) ::
          {:ok, %{entries: [struct()]}} | {:error, :not_found}
  def load(schema, owner, to_entry, opts \\ []) do
    case rows(schema, owner, to_entry, opts) do
      [] -> {:error, :not_found}
      entries -> {:ok, %{entries: entries}}
    end
  end

  defp ordered(query, nil), do: query
  defp ordered(query, column), do: order_by(query, [row], asc: field(row, ^column))

  defp kept(rows, nil), do: rows
  defp kept(rows, keep?) when is_function(keep?, 1), do: Enum.filter(rows, keep?)
end
