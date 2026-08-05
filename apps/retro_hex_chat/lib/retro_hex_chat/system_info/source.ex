defmodule RetroHexChat.SystemInfo.Source do
  @moduledoc """
  A tabular view over some population of runtime entities.

  Processes, ports, sockets, ETS tables and applications differ only in what
  they enumerate and which fields they project. Behind this behaviour they are
  interchangeable, which is what lets one window component serve all five: the
  window is handed a source module and knows nothing else about it.

  A source enumerates and projects; ordering and paging belong to
  `RetroHexChat.SystemInfo.Query` so every source pages identically. `total`
  counts the population *after* filtering and before paging, so a window can
  distinguish "these are all of them" from "these are the first fifty".
  """

  alias RetroHexChat.Admin.Table
  alias RetroHexChat.SystemInfo.Query

  @doc "Columns this source projects, in display order."
  @callback columns() :: [Table.column()]

  @doc "The column a fresh window sorts by."
  @callback default_sort() :: atom()

  @doc """
  Every row matching the query's search term, unordered and unpaged.

  Sources return the full filtered population rather than a page because
  ordering happens across all of it; paging is applied afterwards.

  This runs against every entity on the node, so it must project only fields
  that are cheap to read. Anything expensive belongs in `c:enrich/1`.
  """
  @callback rows(Query.t()) :: [map()]

  @doc """
  Adds detail to the rows that survived paging.

  Some of the most useful columns are the costly ones — a process's real name
  lives in its dictionary, which can be arbitrarily large. Reading those during
  the full scan would make opening a window proportional to the size of the
  node; reading them here bounds the cost to one page, whatever the node holds.
  """
  @callback enrich([map()]) :: [map()]

  @optional_callbacks enrich: 1

  @doc """
  Builds a page of rows from `source` as an `Admin.Table`.

  Returning the same struct the admin windows already render means a runtime
  listing and an audit-log listing are the same thing to the presentation layer.
  """
  @spec table(module(), Query.t()) :: Table.t()
  def table(source, %Query{} = query) do
    rows = source.rows(query)
    query = %{query | sort_by: query.sort_by || source.default_sort()}

    page =
      query
      |> Query.paginate(rows)
      |> enrich_page(source)

    %Table{columns: source.columns(), rows: page, total: length(rows)}
  end

  defp enrich_page(page, source) do
    if function_exported?(source, :enrich, 1), do: source.enrich(page), else: page
  end

  @doc "The keys a source's columns are addressed by, for validating a sort parameter."
  @spec column_keys(module()) :: [atom()]
  def column_keys(source), do: Enum.map(source.columns(), & &1.key)
end
