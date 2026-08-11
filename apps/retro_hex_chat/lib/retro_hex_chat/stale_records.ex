defmodule RetroHexChat.StaleRecords do
  @moduledoc """
  Sweeping the lifecycle rows a process was supposed to close and did not.

  An arcade session, a lobby session and a group-call room each live as a row
  whose `status` walks towards a terminal one and whose `updated_at` moves every
  time the process behind it does something. When that process dies without
  reaching a terminal status — a node restart, a crash — the row is left open
  for good. The sweep finds those: not terminal, and untouched since a cutoff.

  What differs between the three is which table and which statuses count as
  terminal, so that is what a caller declares. Everything else — the ordering
  that makes the sweep resumable, the limit that keeps one pass bounded, and
  the condition re-checked at the moment of the write — is the same question
  asked of three tables.

  Expiring re-states the staleness condition inside the `UPDATE`. Between
  listing a row and writing to it the process behind it may have come back and
  touched it, and reporting `:skipped` for a row that stopped being stale is
  the point: the sweep never closes a session that is alive again.
  """

  import Ecto.Query

  alias RetroHexChat.Repo

  @typedoc "Which table is swept, and which of its statuses mean it is over."
  @type t :: %__MODULE__{schema: module(), terminal_statuses: [String.t()]}

  @enforce_keys [:schema, :terminal_statuses]
  defstruct [:schema, :terminal_statuses]

  @doc """
  Declares a table as sweepable. Cheap enough to hold in a module attribute.
  """
  @spec new(module(), [String.t()]) :: t()
  def new(schema, terminal_statuses)
      when is_atom(schema) and is_list(terminal_statuses) do
    %__MODULE__{schema: schema, terminal_statuses: terminal_statuses}
  end

  @doc """
  The stale rows, oldest first, at most `:limit` of them.

  Oldest first so that a limited pass always takes the rows that have been open
  longest, and so that the next pass continues where this one stopped.
  """
  @spec list(t(), DateTime.t(), keyword()) :: [struct()]
  def list(%__MODULE__{schema: schema} = spec, before, opts \\ []) do
    schema
    |> stale(spec, before)
    |> order_by([r], asc: r.updated_at, asc: r.id)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
  end

  @doc "How many rows the sweep would have to close, ignoring any limit."
  @spec count(t(), DateTime.t()) :: non_neg_integer()
  def count(%__MODULE__{schema: schema} = spec, before) do
    schema
    |> stale(spec, before)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Closes one row as expired, but only while it is still stale.

  Reports `:skipped` when the row no longer matches — it reached a terminal
  status on its own, or something touched it after the cutoff.
  """
  @spec expire(t(), term(), DateTime.t()) :: {:ok, :expired | :skipped} | {:error, term()}
  def expire(%__MODULE__{schema: schema} = spec, id, before) do
    now = DateTime.utc_now()

    {count, _records} =
      schema
      |> where([r], r.id == ^id)
      |> stale(spec, before)
      |> Repo.update_all(
        set: [
          status: "expired",
          closed_at: now,
          closed_reason: "stale_cleanup",
          updated_at: now
        ]
      )

    case count do
      1 -> {:ok, :expired}
      0 -> {:ok, :skipped}
    end
  rescue
    error -> {:error, error}
  end

  defp stale(queryable, %__MODULE__{terminal_statuses: terminal}, before) do
    queryable
    |> where([r], r.status not in ^terminal)
    |> where([r], r.updated_at < ^before)
  end

  defp maybe_limit(query, max_rows) when is_integer(max_rows) and max_rows > 0,
    do: limit(query, ^max_rows)

  defp maybe_limit(query, _max_rows), do: query
end
