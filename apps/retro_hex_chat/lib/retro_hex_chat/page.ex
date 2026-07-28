defmodule RetroHexChat.Page do
  @moduledoc """
  One page of a cursor-paginated list.

  Every paginated `list_*/2` in the domain returns this struct. The pagination
  state it carries — `has_more` and `next_cursor` — is decided from what the
  **database** returned, before any presentation filter runs.

  That ordering is the whole point. A page whose rows are later filtered
  (ignore list, cleared-channel cutoff, channel visibility) keeps the `has_more`
  it was built with, so a filter can never truncate pagination. Use `filter/2`
  and `map/2` to reshape the items; both leave the pagination state alone.

  ## The limit + 1 rule

  A query asks for one row past the page it intends to return:

      limit = Page.limit_with_lookahead(50)   # 51

      rows =
        query
        |> limit(^limit)
        |> Repo.all()

      Page.new(rows, 50, & &1.id)

  If the extra row came back there is another page, and it is dropped from the
  items. This costs one row per query and removes the need for a `COUNT` — and,
  more importantly, removes the judgement call that a `has_more` computed at the
  call site always eventually gets wrong.

  `total` stays `nil` unless the surface actually displays a counter; set it with
  `with_total/2` so an ordinary list never pays for an aggregate.
  """

  @type cursor :: term()

  @type t :: %__MODULE__{
          items: [term()],
          next_cursor: cursor() | nil,
          has_more: boolean(),
          total: non_neg_integer() | nil
        }

  defstruct items: [], next_cursor: nil, has_more: false, total: nil

  @doc """
  The limit a query must use to feed `new/3`: the page size plus the lookahead row.
  """
  @spec limit_with_lookahead(pos_integer()) :: pos_integer()
  def limit_with_lookahead(limit) when is_integer(limit) and limit > 0, do: limit + 1

  @doc """
  Builds a page from the rows a `limit_with_lookahead/1` query returned.

  `limit` is the page size the caller asked for (not the query's limit), and
  `cursor_fun` extracts the cursor value from a row.
  """
  @spec new([term()], pos_integer(), (term() -> cursor())) :: t()
  def new(rows, limit, cursor_fun)
      when is_list(rows) and is_integer(limit) and limit > 0 and is_function(cursor_fun, 1) do
    {items, lookahead} = Enum.split(rows, limit)
    has_more = lookahead != []

    %__MODULE__{
      items: items,
      has_more: has_more,
      next_cursor: next_cursor(items, has_more, cursor_fun)
    }
  end

  @doc "An empty page: nothing in it, nothing after it."
  @spec empty() :: t()
  def empty, do: %__MODULE__{}

  @doc """
  Keeps only the items satisfying `fun`, leaving `has_more` and `next_cursor` intact.

  This is how a presentation filter is applied to a page. Rebuilding the struct
  by hand instead would reintroduce exactly the bug this module exists to remove.
  """
  @spec filter(t(), (term() -> as_boolean(term()))) :: t()
  def filter(%__MODULE__{} = page, fun) when is_function(fun, 1) do
    %{page | items: Enum.filter(page.items, fun)}
  end

  @doc "Transforms every item, leaving `has_more` and `next_cursor` intact."
  @spec map(t(), (term() -> term())) :: t()
  def map(%__MODULE__{} = page, fun) when is_function(fun, 1) do
    %{page | items: Enum.map(page.items, fun)}
  end

  @doc "Attaches the total row count, for surfaces that display a counter."
  @spec with_total(t(), non_neg_integer()) :: t()
  def with_total(%__MODULE__{} = page, total) when is_integer(total) and total >= 0 do
    %{page | total: total}
  end

  # The cursor is the last row the DATABASE returned for this page, taken before
  # any filtering — a cursor derived from the last *visible* row would make the
  # next page re-fetch whatever this one hid.
  @spec next_cursor([term()], boolean(), (term() -> cursor())) :: cursor() | nil
  defp next_cursor(_items, false, _cursor_fun), do: nil
  defp next_cursor([], true, _cursor_fun), do: nil
  defp next_cursor(items, true, cursor_fun), do: items |> List.last() |> cursor_fun.()
end
