defmodule RetroHexChat.SystemInfo.Query do
  @moduledoc """
  How a caller asks a `RetroHexChat.SystemInfo.Source` for rows.

  Every tabular view over the runtime — processes, ports, sockets, ETS tables,
  applications — is the same question with different nouns: filter by a term,
  order by a column, take the first N. This struct is that question, so a source
  implements one `list/1` rather than one function per combination.

  `sort_by` is an atom because it indexes a row map, and atoms are never built
  from caller input: `new/2` accepts the column keys a source declares and
  resolves the parameter against that list. An unknown column falls back to the
  source's default rather than raising, because a stale sort in a bookmarked
  window should render the table, not an error page.
  """

  @type sort_dir :: :asc | :desc

  @type t :: %__MODULE__{
          search: String.t() | nil,
          sort_by: atom() | nil,
          sort_dir: sort_dir(),
          limit: pos_integer()
        }

  defstruct search: nil, sort_by: nil, sort_dir: :desc, limit: 50

  @default_limit 50
  @max_limit 500

  @doc """
  Builds a query from user-supplied params against a source's column keys.

  `columns` bounds what `sort_by` may become. The limit is clamped rather than
  rejected: a window asking for everything gets the largest page the runtime is
  willing to walk, which keeps a mistyped parameter from turning into a scan of
  every process on the node.
  """
  @spec new(map(), [atom()]) :: t()
  def new(params, columns) when is_map(params) and is_list(columns) do
    %__MODULE__{
      search: normalize_search(params["search"]),
      sort_by: resolve_sort_by(params["sort_by"], columns),
      sort_dir: resolve_sort_dir(params["sort_dir"]),
      limit: resolve_limit(params["limit"])
    }
  end

  @doc "Flips the direction for `column`, or starts a fresh descending sort on it."
  @spec toggle_sort(t(), atom()) :: t()
  def toggle_sort(%__MODULE__{sort_by: column, sort_dir: dir} = query, column) do
    %{query | sort_dir: flip(dir)}
  end

  def toggle_sort(%__MODULE__{} = query, column) when is_atom(column) do
    %{query | sort_by: column, sort_dir: :desc}
  end

  @doc "Whether `term` matches any of `values`, case-insensitively."
  @spec matches?(nil | String.t(), [term()]) :: boolean()
  def matches?(nil, _values), do: true

  def matches?(term, values) when is_binary(term) and is_list(values) do
    term = String.downcase(term)
    Enum.any?(values, &(&1 |> to_string() |> String.downcase() |> String.contains?(term)))
  end

  @doc """
  Orders rows by the query's column and direction, then takes one page.

  Rows missing the sort key sort as if they held zero, so a source whose column
  is sparse still orders deterministically instead of raising on `nil`.
  """
  @spec paginate(t(), [map()]) :: [map()]
  def paginate(%__MODULE__{sort_by: nil, limit: limit}, rows), do: Enum.take(rows, limit)

  def paginate(%__MODULE__{sort_by: key, sort_dir: dir, limit: limit}, rows) do
    rows
    |> Enum.sort_by(&sort_key(&1, key), sorter(dir))
    |> Enum.take(limit)
  end

  defp sort_key(row, key) do
    case Map.get(row, key) do
      nil -> 0
      value when is_binary(value) -> String.downcase(value)
      value -> value
    end
  end

  # Comparing mixed types would raise on a column that holds numbers for some
  # rows and strings for others, which the runtime tables genuinely do.
  defp sorter(:asc), do: &compare_le/2
  defp sorter(:desc), do: &compare_ge/2

  defp compare_le(left, right), do: compare(left, right) != :gt
  defp compare_ge(left, right), do: compare(left, right) != :lt

  defp compare(left, right) when is_number(left) and is_number(right) do
    cond do
      left < right -> :lt
      left > right -> :gt
      true -> :eq
    end
  end

  defp compare(left, right) when is_binary(left) and is_binary(right) do
    cond do
      left < right -> :lt
      left > right -> :gt
      true -> :eq
    end
  end

  defp compare(left, right), do: compare(to_string(left), to_string(right))

  defp flip(:asc), do: :desc
  defp flip(:desc), do: :asc

  defp normalize_search(term) when is_binary(term) do
    case String.trim(term) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_search(_term), do: nil

  defp resolve_sort_by(value, columns) when is_binary(value) do
    Enum.find(columns, fn column -> Atom.to_string(column) == value end)
  end

  defp resolve_sort_by(value, columns) when is_atom(value) and not is_nil(value) do
    if value in columns, do: value
  end

  defp resolve_sort_by(_value, _columns), do: nil

  defp resolve_sort_dir("asc"), do: :asc
  defp resolve_sort_dir(:asc), do: :asc
  defp resolve_sort_dir(_value), do: :desc

  defp resolve_limit(value) when is_integer(value), do: clamp(value)

  defp resolve_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} -> clamp(parsed)
      :error -> @default_limit
    end
  end

  defp resolve_limit(_value), do: @default_limit

  defp clamp(value) when value < 1, do: @default_limit
  defp clamp(value) when value > @max_limit, do: @max_limit
  defp clamp(value), do: value
end
