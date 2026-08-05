defmodule RetroHexChat.Admin.Table do
  @moduledoc """
  The structured half of an admin command's reply.

  `/admin` answers a listing command with a block of preformatted text, because
  its first home was the chat log. The admin windows render that same text, so
  they have no rows, no ids and no way to paginate.

  Rather than replace the text — which every `/admin` user in chat still reads —
  a listing handler now carries this alongside it:

      {:ok, :system, %{content: text, table: %Table{}}}

  The chat path keeps matching on `content` and is untouched; the windows read
  `table` and render rows. The text cannot regress, because it is still produced
  by the same code that produced it before.

  `page` carries the pagination state when the underlying query is paginated,
  and is `nil` for a bounded listing.
  """

  alias RetroHexChat.Page

  @type format :: :text | :bytes | :number | :duration_ms | :percent

  @type column :: %{
          key: atom(),
          label: String.t(),
          format: format(),
          sortable: boolean()
        }

  @type t :: %__MODULE__{
          columns: [column()],
          rows: [map()],
          total: non_neg_integer() | nil,
          page: Page.t() | nil
        }

  defstruct columns: [], rows: [], total: nil, page: nil

  @doc """
  Builds a table from a `Page`, projecting each item into a row.

  The page's own accounting travels with the table, so a window can tell
  truncation from exhaustion without asking again.
  """
  @spec from_page([column()], Page.t(), (term() -> map())) :: t()
  def from_page(columns, %Page{} = page, row_fun) when is_function(row_fun, 1) do
    %__MODULE__{
      columns: columns,
      rows: Enum.map(page.items, row_fun),
      total: page.total,
      page: page
    }
  end

  @doc "Builds a table from a bounded list, with no pagination state to carry."
  @spec from_list([column()], [term()], (term() -> map())) :: t()
  def from_list(columns, items, row_fun) when is_list(items) and is_function(row_fun, 1) do
    %__MODULE__{columns: columns, rows: Enum.map(items, row_fun)}
  end

  @doc """
  Adds a later page's rows under the ones already on screen.

  A window paginates by dispatching the same command again with a cursor; what
  comes back is a whole table describing only the new page. Appending here keeps
  the accumulated rows in one place and adopts the newer page's accounting, so
  the cursor and `has_more` always describe the *last* page fetched rather than
  the first.

  The columns come from the table already on screen: they are a property of the
  listing, not of any one page, and taking the newer ones would let a mid-scroll
  change of shape reorder the columns under the reader.
  """
  @spec append(t(), t()) :: t()
  def append(%__MODULE__{} = table, %__MODULE__{} = next) do
    %{table | rows: table.rows ++ next.rows, page: next.page, total: next.total || table.total}
  end

  @doc "Whether the listing has rows beyond the ones carried here."
  @spec has_more?(t()) :: boolean()
  def has_more?(%__MODULE__{page: %Page{has_more: has_more}}), do: has_more
  def has_more?(%__MODULE__{}), do: false

  @doc "The cursor for the next page, or nil."
  @spec next_cursor(t()) :: Page.cursor() | nil
  def next_cursor(%__MODULE__{page: %Page{next_cursor: cursor}}), do: cursor
  def next_cursor(%__MODULE__{}), do: nil

  @doc """
  Declares a column.

  `format` tells the renderer how to read the cell — a byte count and a plain
  integer are both integers, and only the column knows which one it is. It
  defaults to `:text`, which is what every listing that predates the option
  already got. `sortable` is opt-in for the same reason: the audit log is
  ordered by the query behind it, not by clicking a heading.
  """
  @spec column(atom(), String.t(), keyword()) :: column()
  def column(key, label, opts \\ []) do
    %{
      key: key,
      label: label,
      format: Keyword.get(opts, :format, :text),
      sortable: Keyword.get(opts, :sortable, false)
    }
  end
end
