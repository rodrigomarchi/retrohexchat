defmodule RetroHexChat.Moderation.TimedRestriction do
  @moduledoc """
  The lifecycle shared by durable moderation restrictions.

  A restriction names a subject, optionally ends at a moment, and may be lifted
  before that moment by an operator or by the system. Expiry is *materialised*
  by a scheduled job rather than inferred at read time, so the row itself always
  states whether it is still in force and a reader never has to reproduce the
  rule. A restriction reaching its moment therefore has two representations in
  sequence — due, then revoked — and `expire_due/3` is what moves it between
  them.

  A context declares its shape once with `new!/1` and hands that declaration to
  every function here. The columns it names are checked against the schema while
  the calling module compiles, so a renamed column fails the build rather than a
  request.

  What a caller keeps for itself is what genuinely differs: which rows are in
  scope, what a row is called, and what else must happen when one is written.
  """

  import Ecto.Query

  alias RetroHexChat.Jobs
  alias RetroHexChat.Repo

  @system_actor "system"
  @manual_revocation "manual"
  @expired_revocation "expired"

  @lifecycle_fields [
    :expires_at,
    :revoked_at,
    :revoked_by_nickname,
    :revoke_reason,
    :inserted_at,
    :updated_at
  ]

  @enforce_keys [
    :schema,
    :worker,
    :queue,
    :job_args_key,
    :subject_attr,
    :subject_field,
    :scope_fields
  ]
  defstruct @enforce_keys

  @typedoc """
  A context's declaration of one kind of restriction.

  * `:schema` — the Ecto schema holding the rows
  * `:worker` — the Oban worker that materialises a single row's expiry
  * `:queue` — the queue that worker runs on, needed to cancel a pending job
  * `:job_args_key` — the key carrying the row id in that job's args
  * `:subject_attr` — the column naming the restricted party as written
  * `:subject_field` — the normalized column matched when looking a subject up
  * `:scope_fields` — columns narrowing a subject to one scope, empty when
    the restriction is server-wide
  """
  @type t :: %__MODULE__{
          schema: module(),
          worker: module(),
          queue: atom(),
          job_args_key: atom(),
          subject_attr: atom(),
          subject_field: atom(),
          scope_fields: [atom()]
        }

  @type record :: Ecto.Schema.t()
  @type scope :: keyword()
  @type revoke_summary :: %{revoked: non_neg_integer()}
  @type expiry_result ::
          {:expired, record()}
          | {:noop, record()}
          | {:not_due, record(), pos_integer()}

  @doc """
  Declares a restriction, refusing at compile time to name a column the schema
  does not have or a schema missing the lifecycle columns this module writes.
  """
  @spec new!(keyword()) :: t()
  def new!(opts) do
    restriction = struct!(__MODULE__, opts)
    known = restriction.schema.__schema__(:fields)
    declared = [restriction.subject_attr, restriction.subject_field | restriction.scope_fields]

    case Enum.reject(declared ++ @lifecycle_fields, &(&1 in known)) do
      [] ->
        restriction

      missing ->
        raise ArgumentError,
              "#{inspect(restriction.schema)} has no field(s) #{inspect(missing)}; " <>
                "a timed restriction needs them to record who lifted a row and when"
    end
  end

  @doc """
  Writes the restriction in force for a subject and schedules its expiry.

  An unrevoked row for the same subject and scope is rewritten rather than
  duplicated, which is what makes re-restricting someone extend the existing
  record instead of racing it. Any expiry job left over from the previous
  duration is cancelled before the new one is scheduled.

  `attrs` carries the caller's own columns; the revocation columns are cleared
  and `expires_at` is derived from `duration`, where anything other than a
  positive integer of seconds means the restriction does not end on its own.
  """
  @spec put(t(), map(), non_neg_integer() | :permanent, keyword()) ::
          {:ok, record()} | {:error, term()}
  def put(%__MODULE__{} = restriction, attrs, duration, opts \\ []) do
    now = now(opts)

    attrs =
      Map.merge(attrs, %{
        expires_at: expires_at(duration, now),
        revoked_at: nil,
        revoked_by_nickname: nil,
        revoke_reason: nil
      })

    Repo.transaction(fn ->
      with {:ok, record} <- upsert_unrevoked(restriction, attrs),
           :ok <- replace_expiry_job(restriction, record) do
        record
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Lifts every unrevoked restriction on a subject and drops their pending expiry
  jobs, recording who did it.
  """
  @spec revoke_active(t(), String.t(), String.t(), keyword()) ::
          {:ok, revoke_summary()} | {:error, term()}
  def revoke_active(%__MODULE__{} = restriction, subject, actor, opts \\ []) do
    now = now(opts)
    scope = Keyword.get(opts, :scope, [])

    Repo.transaction(fn ->
      records =
        restriction
        |> unrevoked_query(subject, scope)
        |> Repo.all()

      with :ok <- cancel_expiry_jobs(restriction, records) do
        %{revoked: mark_revoked(restriction, records, actor, @manual_revocation, now)}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Materialises one due restriction as revoked by the system.

  The three non-expiring outcomes are distinguished rather than collapsed, so
  the caller can tell a row that was already lifted from one whose moment has
  not arrived: `{:noop, record}` for the former and `{:not_due, record, seconds}`
  for the latter, where `seconds` is how long to wait before asking again.
  A row that cannot expire at all rolls the transaction back with `:not_found`
  or `:permanent_restriction`, which is a job to cancel rather than retry.

  `:on_expired` runs inside the transaction, so raising from it undoes the
  expiry — which is what a caller keeping a derived cache in step wants.
  """
  @spec expire_due(t(), pos_integer(), keyword()) :: {:ok, expiry_result()} | {:error, term()}
  def expire_due(%__MODULE__{} = restriction, id, opts \\ []) when is_integer(id) and id > 0 do
    now = now(opts)
    on_expired = Keyword.get(opts, :on_expired)

    Repo.transaction(fn ->
      case mark_expired(restriction, id, now) do
        {:ok, record} ->
          run_hook(on_expired, record)
          {:expired, record}

        {:skip, outcome} ->
          outcome
      end
    end)
  end

  @doc "Lists the restrictions in force, ordered by the subject as written."
  @spec list_active(t(), keyword()) :: [record()]
  def list_active(%__MODULE__{} = restriction, opts \\ []) do
    restriction
    |> active_query(Keyword.get(opts, :scope, []), now(opts))
    |> order_by(^[asc: restriction.subject_attr])
    |> Repo.all()
  end

  @doc "Counts the restrictions in force."
  @spec active_count(t(), keyword()) :: non_neg_integer()
  def active_count(%__MODULE__{} = restriction, opts \\ []) do
    restriction
    |> active_query(Keyword.get(opts, :scope, []), now(opts))
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts the restrictions whose moment has passed but whose expiry has not been
  materialised — a backlog, and therefore a health signal rather than a total.
  """
  @spec due_count(t(), keyword()) :: non_neg_integer()
  def due_count(%__MODULE__{} = restriction, opts \\ []) do
    restriction
    |> due_query(now(opts))
    |> Repo.aggregate(:count, :id)
  end

  defp upsert_unrevoked(restriction, attrs) do
    subject = Map.fetch!(attrs, restriction.subject_attr)
    scope = attrs |> Map.take(restriction.scope_fields) |> Map.to_list()

    changeset =
      case latest_unrevoked(restriction, subject, scope) do
        nil -> restriction.schema.changeset(struct(restriction.schema), attrs)
        record -> restriction.schema.changeset(record, attrs)
      end

    Repo.insert_or_update(changeset)
  end

  defp latest_unrevoked(restriction, subject, scope) do
    restriction
    |> unrevoked_query(subject, scope)
    |> order_by([row], desc: row.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp mark_revoked(_restriction, [], _actor, _reason, _now), do: 0

  defp mark_revoked(restriction, records, actor, reason, now) do
    ids = Enum.map(records, & &1.id)

    restriction.schema
    |> where([row], row.id in ^ids)
    |> where([row], is_nil(row.revoked_at))
    |> Repo.update_all(
      set: [
        revoked_at: now,
        revoked_by_nickname: actor,
        revoke_reason: reason,
        updated_at: now
      ]
    )
    |> elem(0)
  end

  defp mark_expired(restriction, id, now) do
    query =
      restriction.schema
      |> where([row], row.id == ^id)
      |> due_where(now)

    {count, _records} =
      Repo.update_all(query,
        set: [
          revoked_at: now,
          revoked_by_nickname: @system_actor,
          revoke_reason: @expired_revocation,
          updated_at: now
        ]
      )

    case count do
      1 -> {:ok, Repo.get!(restriction.schema, id)}
      0 -> {:skip, classify_not_expired(restriction, id, now)}
    end
  end

  defp classify_not_expired(restriction, id, now) do
    case Repo.get(restriction.schema, id) do
      nil ->
        Repo.rollback(:not_found)

      %{revoked_at: %DateTime{}} = record ->
        {:noop, record}

      %{expires_at: nil} ->
        Repo.rollback(:permanent_restriction)

      %{expires_at: %DateTime{} = expires_at} = record ->
        {:not_due, record, max(DateTime.diff(expires_at, now, :second), 1)}
    end
  end

  defp replace_expiry_job(restriction, record) do
    with :ok <- cancel_expiry_jobs(restriction, [record]) do
      schedule_expiry_job(restriction, record)
    end
  end

  defp schedule_expiry_job(_restriction, %{expires_at: nil}), do: :ok

  defp schedule_expiry_job(restriction, %{id: id, expires_at: %DateTime{} = expires_at}) do
    %{restriction.job_args_key => id}
    |> restriction.worker.new(scheduled_at: expires_at)
    |> Jobs.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp cancel_expiry_jobs(restriction, records) do
    args_key = Atom.to_string(restriction.job_args_key)

    Enum.each(records, fn record ->
      {:ok, _count} =
        Jobs.cancel_worker_jobs(restriction.worker, restriction.queue, %{args_key => record.id})
    end)

    :ok
  end

  defp unrevoked_query(restriction, subject, scope) do
    subject_field = restriction.subject_field

    restriction.schema
    |> where([row], is_nil(row.revoked_at))
    |> where([row], field(row, ^subject_field) == ^normalize(subject))
    |> scope_where(scope)
  end

  defp active_query(restriction, scope, now) do
    restriction.schema
    |> where([row], is_nil(row.revoked_at))
    |> where([row], is_nil(row.expires_at) or row.expires_at > ^now)
    |> scope_where(scope)
  end

  defp due_query(restriction, now), do: due_where(restriction.schema, now)

  defp due_where(query, now) do
    query
    |> where([row], is_nil(row.revoked_at))
    |> where([row], not is_nil(row.expires_at))
    |> where([row], row.expires_at <= ^now)
  end

  defp scope_where(query, scope) do
    Enum.reduce(scope, query, fn {key, value}, acc ->
      where(acc, [row], field(row, ^key) == ^value)
    end)
  end

  defp expires_at(duration, now) when is_integer(duration) and duration > 0,
    do: DateTime.add(now, duration, :second)

  defp expires_at(_duration, _now), do: nil

  defp normalize(subject) when is_binary(subject), do: String.downcase(subject)

  defp now(opts), do: Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

  defp run_hook(nil, _record), do: :ok
  defp run_hook(hook, record) when is_function(hook, 1), do: hook.(record)
end
