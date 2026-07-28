defmodule RetroHexChatWeb.PaginatedList.State do
  @moduledoc """
  Pagination state for one list, as a plain struct.

  Kept free of sockets and streams so the rules that matter — when another page
  may be requested, what to ask the server for, what the hook is allowed to do —
  are unit testable on their own. `RetroHexChatWeb.PaginatedList` wires this to a
  LiveComponent's stream.

  One island frequently owns several lists (Channel Central has four, the Bot
  Form has three), so state is per-list and named by the caller rather than
  living loose in the island's assigns.
  """

  alias RetroHexChat.Page

  @default_page_size 50

  # Enough rows above and below the reader to read as an infinite list, few
  # enough that the browser stays fast. The ratio LiveView's own documentation
  # recommends for stream-backed infinite scroll.
  @dom_pages 3

  @type t :: %__MODULE__{
          count: non_neg_integer(),
          cursor: Page.cursor() | nil,
          error?: boolean(),
          has_more: boolean(),
          loaded?: boolean(),
          loading?: boolean(),
          page_size: pos_integer(),
          total: non_neg_integer() | nil
        }

  defstruct count: 0,
            cursor: nil,
            error?: false,
            has_more: false,
            loaded?: false,
            loading?: false,
            page_size: @default_page_size,
            total: nil

  @doc "A fresh state for a list that has not loaded anything yet."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{page_size: Keyword.get(opts, :page_size, @default_page_size)}
  end

  @doc "How many rows this list keeps in the DOM."
  @spec dom_limit(t()) :: pos_integer()
  def dom_limit(%__MODULE__{page_size: page_size}), do: page_size * @dom_pages

  @doc """
  Whether another page may be requested right now.

  Requires a cursor as well as `has_more`: asking with a nil cursor would re-read
  the first page forever, which looks like a working list that never advances.
  """
  @spec can_load_more?(t()) :: boolean()
  def can_load_more?(%__MODULE__{has_more: true, loading?: false, cursor: cursor})
      when not is_nil(cursor),
      do: true

  def can_load_more?(%__MODULE__{}), do: false

  @doc "Marks a request in flight."
  @spec loading(t()) :: t()
  def loading(%__MODULE__{} = state), do: %{state | loading?: true}

  @doc """
  Adopts the pagination state of a page that just landed, clearing the in-flight flag.

  `total` is only overwritten when the page carries one, so a surface that
  counts once and paginates after does not lose the count.
  """
  @spec from_page(t(), Page.t()) :: t()
  def from_page(%__MODULE__{} = state, %Page{} = page) do
    %{
      state
      | count: state.count + length(page.items),
        cursor: page.next_cursor,
        error?: false,
        has_more: page.has_more,
        loaded?: true,
        loading?: false,
        total: page.total || state.total
    }
  end

  @doc """
  Records that a page could not be fetched.

  The cursor is kept on purpose: the reader has not moved, so retrying must ask
  for the same page again. Clearing it would turn a failed load into a silently
  shortened list, which is exactly what the error state exists to prevent.
  """
  @spec failed(t()) :: t()
  def failed(%__MODULE__{} = state), do: %{state | error?: true, loading?: false}

  @doc """
  The predicates a template asks about a list.

  All four accept `nil` as well as a state, because a presentational component
  takes its state as an optional attribute: rendered standalone — in the
  showcase, or by `render_component/2` in a test — it has none and must degrade
  to a plain list rather than raise. Every predicate is false in that case, so
  no pagination furniture appears around a list that is not paginated.
  """
  @spec loaded?(t() | nil) :: boolean()
  def loaded?(%__MODULE__{loaded?: loaded?}), do: loaded?
  def loaded?(nil), do: false

  @doc """
  Whether the list is loaded and has nothing in it.

  A stream carries no count into the markup, so this is the only way a template
  can tell an empty list from one whose first page has not landed — without it
  every list would flash its empty state while loading.
  """
  @spec empty?(t() | nil) :: boolean()
  def empty?(%__MODULE__{loaded?: true, count: 0}), do: true
  def empty?(%__MODULE__{}), do: false
  def empty?(nil), do: false

  @doc """
  Whether the list has rows and nothing follows them.

  Distinct from `empty?/1` so the end marker and the empty state can never both
  render: "end of list" under a list with no rows reads as a failure.
  """
  @spec exhausted?(t() | nil) :: boolean()
  def exhausted?(%__MODULE__{has_more: false, count: count}) when count > 0, do: true
  def exhausted?(%__MODULE__{}), do: false
  def exhausted?(nil), do: false

  @doc "Whether another page exists, as far as the template is concerned."
  @spec more?(t() | nil) :: boolean()
  def more?(%__MODULE__{has_more: has_more}), do: has_more
  def more?(nil), do: false

  @doc "Whether a page is in flight, as far as the template is concerned."
  @spec loading?(t() | nil) :: boolean()
  def loading?(%__MODULE__{loading?: loading?}), do: loading?
  def loading?(nil), do: false

  @doc """
  Whether the last attempt to fetch a page failed.

  Without this a failed page is indistinguishable from the end of the list: the
  rows simply stop, and the reader concludes there is nothing more.
  """
  @spec error?(t() | nil) :: boolean()
  def error?(%__MODULE__{error?: error?}), do: error?
  def error?(nil), do: false

  @doc "Back to the initial state, keeping the configuration."
  @spec reset(t()) :: t()
  def reset(%__MODULE__{page_size: page_size}), do: new(page_size: page_size)

  @doc "The options to pass to the domain's `list_*/2` for the next page."
  @spec query_opts(t()) :: keyword()
  def query_opts(%__MODULE__{cursor: nil, page_size: page_size}), do: [limit: page_size]

  def query_opts(%__MODULE__{cursor: cursor, page_size: page_size}),
    do: [limit: page_size, cursor: cursor]

  @doc """
  The `data-*` the `InfiniteScrollHook` reads.

  The hook binding itself is deliberately absent. The hooks contract check
  (`assets/scripts/enforce_hooks_contract.cjs`) scans the markup for a literal
  binding string, so it has to be written in the template — generating it here
  would make CI report the hook as unused.
  """
  @spec hook_attrs(t()) :: %{String.t() => String.t()}
  def hook_attrs(%__MODULE__{} = state) do
    %{
      "data-has-more" => to_string(state.has_more),
      "data-loading" => to_string(state.loading?)
    }
  end
end
