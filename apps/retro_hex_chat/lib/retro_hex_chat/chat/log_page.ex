defmodule RetroHexChat.Chat.LogPage do
  @moduledoc """
  In-memory pagination result wrapper for the Log Viewer.
  Wraps a page of query results with metadata for pagination controls.
  """

  alias RetroHexChat.Chat.LogFilter

  @type t :: %__MODULE__{
          entries: [map()],
          total_count: non_neg_integer(),
          page: pos_integer(),
          total_pages: non_neg_integer(),
          filter: LogFilter.t()
        }

  defstruct entries: [],
            total_count: 0,
            page: 1,
            total_pages: 0,
            filter: nil

  @doc """
  Creates a new LogPage from query results.

  Takes the list of entries, the total count of matching records, and
  the `LogFilter` that produced the results. Computes `total_pages`
  from `total_count` and `filter.per_page`.

  ## Examples

      iex> filter = LogFilter.new()
      iex> page = LogPage.new([], 0, filter)
      iex> page.total_pages
      0

      iex> filter = LogFilter.new()
      iex> page = LogPage.new(entries, 101, filter)
      iex> page.total_pages
      3
  """
  @spec new(list(), non_neg_integer(), LogFilter.t()) :: t()
  def new(entries, total_count, %LogFilter{} = filter)
      when is_list(entries) and is_integer(total_count) and total_count >= 0 do
    total_pages = compute_total_pages(total_count, filter.per_page)

    %__MODULE__{
      entries: entries,
      total_count: total_count,
      page: filter.page,
      total_pages: total_pages,
      filter: filter
    }
  end

  defp compute_total_pages(0, _per_page), do: 0

  defp compute_total_pages(total_count, per_page) do
    ceil(total_count / per_page)
  end
end
