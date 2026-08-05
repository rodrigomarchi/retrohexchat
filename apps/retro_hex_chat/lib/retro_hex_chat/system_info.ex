defmodule RetroHexChat.SystemInfo do
  @moduledoc """
  Introspection of the running node: what it is, what it holds, how it is coping.

  This is a bounded context in its own right rather than a corner of `Admin`,
  because none of it depends on administrative authority. Reading the process
  count is not a privileged domain operation; it becomes one only because the
  web layer decides who may open the window. Keeping the two apart means the
  gate can move — to a health endpoint, to a release task, to a test — without
  dragging audit logs and role checks behind it.

  Five of the views are populations that differ only in what they enumerate, so
  they are `RetroHexChat.SystemInfo.Source` implementations addressed by name
  and served by one query path. The rest are single readings with shapes of
  their own: the node's vitals, its allocators, its host, its database.

  Everything here reads; nothing here writes. A caller cannot use this module
  to change the node, which is what makes it safe to put behind a refresh loop.
  """

  alias RetroHexChat.Admin.Table
  alias RetroHexChat.SystemInfo.{Allocators, Database, Instance, OS, Query, Runtime, Source}
  alias RetroHexChat.SystemInfo.Sources

  @sources %{
    processes: Sources.Processes,
    ports: Sources.Ports,
    sockets: Sources.Sockets,
    ets: Sources.Ets,
    applications: Sources.Applications,
    allocators: Allocators
  }

  @type source_name ::
          :processes | :ports | :sockets | :ets | :applications | :allocators

  @doc "The names every tabular view is addressed by."
  @spec source_names() :: [source_name()]
  def source_names, do: Map.keys(@sources)

  @doc """
  Resolves a source name, accepting the string form a window sends.

  Returns an error rather than raising for an unknown name: the name travels
  through the client, and a stale one should render an empty window instead of
  crashing the LiveView that owns it.
  """
  @spec fetch_source(atom() | String.t()) :: {:ok, module()} | {:error, :unknown_source}
  def fetch_source(name) when is_atom(name) do
    case Map.fetch(@sources, name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unknown_source}
    end
  end

  def fetch_source(name) when is_binary(name) do
    case Enum.find(@sources, fn {key, _module} -> Atom.to_string(key) == name end) do
      {_key, module} -> {:ok, module}
      nil -> {:error, :unknown_source}
    end
  end

  @doc "Builds a query bounded by what `source` declares it can be sorted by."
  @spec query(module(), map()) :: Query.t()
  def query(source, params) when is_map(params) do
    Query.new(params, Source.column_keys(source))
  end

  @doc "Lists one page of a source as a table."
  @spec list(module(), Query.t()) :: Table.t()
  def list(source, %Query{} = query), do: Source.table(source, query)

  @doc "The node's fixed description, reporting the versions of `apps`."
  @spec info([atom()]) :: Runtime.Info.t()
  defdelegate info(apps \\ []), to: Runtime

  @doc "One reading of the node's vitals."
  @spec usage() :: Runtime.Snapshot.t()
  defdelegate usage, to: Runtime

  @doc "Per-allocator block and carrier sizes, totals first."
  @spec allocators() :: [Allocators.t()]
  defdelegate allocators(), to: Allocators, as: :current

  @doc "Columns describing an allocator reading."
  @spec allocator_columns() :: [Table.column()]
  defdelegate allocator_columns(), to: Allocators, as: :columns

  @doc "The host's own gauges, as far as `:os_mon` can report them."
  @spec os() :: OS.t()
  defdelegate os(), to: OS, as: :current

  @doc "Whether the host gauges can be read at all on this node."
  @spec os_available?() :: boolean()
  defdelegate os_available?(), to: OS, as: :available?

  @doc "What the application itself is currently carrying."
  @spec instance() :: Instance.t()
  defdelegate instance(), to: Instance, as: :current

  @doc "Per-channel occupancy as a table."
  @spec channel_table(Instance.t()) :: Table.t()
  defdelegate channel_table(instance), to: Instance

  @doc "The database reports this surface is willing to run."
  @spec database_reports(module()) :: [Database.report()]
  defdelegate database_reports(repo), to: Database, as: :reports

  @doc "Runs one database report."
  @spec run_database_report(module(), atom() | String.t()) ::
          {:ok, Table.t()} | {:error, :unknown_report | :query_failed}
  defdelegate run_database_report(repo, name), to: Database, as: :run
end
