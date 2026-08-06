defmodule RetroHexChat.SystemInfo.Database do
  @moduledoc """
  Diagnostic reports about the PostgreSQL instance behind the repo.

  `ecto_psql_extras` ships a catalogue of queries answering the questions that
  matter when a database is misbehaving: which indexes are never used, what is
  bloated, what is blocking, whether the cache is being hit. This module is the
  boundary that decides which of them a monitoring window may run, and turns
  their results into the same `Table` every other listing uses.

  Two exclusions are deliberate:

    * `kill_all` terminates every connection to the database. It is a
      maintenance action wearing the shape of a report, and a window whose
      whole idiom is "pick a report and read it" must not be able to reach it.

    * `mandelbrot` renders ASCII art. It is a demonstration of the query
      engine, not a diagnostic.

  Reports needing an argument — a specific table's schema or foreign keys — are
  also withheld, because selecting the argument is a different interaction than
  picking a report, and offering them without the picker would only produce
  errors.
  """

  alias RetroHexChat.Table

  @type report :: %{name: atom(), title: String.t()}

  @withheld [:kill_all, :mandelbrot]

  @doc """
  Every report this surface is willing to run, in display order.

  Ordered by title rather than by the catalogue's internal ordering, because
  the reader is picking from a list of names.
  """
  @spec reports(module()) :: [report()]
  def reports(repo) do
    repo
    |> EctoPSQLExtras.queries()
    |> Enum.reject(fn {name, module} -> withheld?(name, module) end)
    |> Enum.map(fn {name, module} -> %{name: name, title: title(name, module)} end)
    |> Enum.sort_by(& &1.title)
  end

  @doc """
  Runs a report, returning its rows as a table.

  Guards the report name against the allowed set rather than trusting the
  caller: the name arrives from a window as a string, and the catalogue
  contains entries this surface has decided not to expose.
  """
  @spec run(module(), atom() | String.t(), keyword()) ::
          {:ok, Table.t()} | {:error, :unknown_report | :query_failed}
  def run(repo, name, opts \\ []) do
    with {:ok, name} <- fetch_report(repo, name) do
      execute(repo, name, opts)
    end
  end

  @doc "Resolves a report name supplied as a string against the allowed set."
  @spec fetch_report(module(), atom() | String.t()) :: {:ok, atom()} | {:error, :unknown_report}
  def fetch_report(repo, name) do
    allowed = reports(repo)

    case Enum.find(allowed, fn report -> to_string(report.name) == to_string(name) end) do
      nil -> {:error, :unknown_report}
      report -> {:ok, report.name}
    end
  end

  defp execute(repo, name, opts) do
    module = Map.fetch!(EctoPSQLExtras.queries(repo), name)
    result = EctoPSQLExtras.query(name, repo, Keyword.merge([format: :raw, log: false], opts))

    {:ok, to_table(module, result)}
  rescue
    # A report can fail for reasons entirely outside this node: a missing
    # extension, a permission the role lacks, a lock it cannot take. None of
    # them should take the window down with it.
    _error -> {:error, :query_failed}
  end

  # The declared columns are the source of both the key and the format: their
  # names are atoms the library already interned, so no column name arriving
  # from Postgres is ever turned into one here, and their types say what a
  # figure means without this module having to infer it from the value.
  defp to_table(module, %{rows: rows}) do
    declared = module.info()[:columns] || []

    %Table{
      columns: Enum.map(declared, &column/1),
      rows: Enum.with_index(rows, &row(&1, &2, declared)),
      total: length(rows)
    }
  end

  defp column(%{name: name, type: type}) do
    Table.column(name, name |> to_string() |> String.replace("_", " "),
      format: format(type),
      sortable: true
    )
  end

  defp format(:bytes), do: :bytes
  defp format(:percent), do: :percent
  defp format(type) when type in [:int, :integer, :numeric], do: :number
  defp format(_type), do: :text

  defp row(values, index, declared) do
    declared
    |> Enum.zip(values)
    |> Enum.into(%{id: index}, fn {%{name: name}, value} -> {name, cell(value)} end)
  end

  defp cell(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp cell(value) when is_list(value), do: Enum.map_join(value, ", ", &cell/1)
  defp cell(value) when is_binary(value) or is_number(value) or is_boolean(value), do: value
  defp cell(nil), do: nil
  defp cell(value), do: inspect(value)

  defp withheld?(name, module) do
    name in @withheld or requires_argument?(module)
  end

  defp requires_argument?(module) do
    function_exported?(module, :info, 0) and Map.has_key?(module.info(), :args_for_select)
  end

  defp title(name, module) do
    if function_exported?(module, :info, 0) do
      Map.get(module.info(), :title, to_string(name))
    else
      to_string(name)
    end
  end
end
