defmodule RetroHexChat.Chat.LogFilter do
  @moduledoc """
  In-memory struct holding search criteria for the Log Viewer.
  Used to filter and paginate chat history logs by source, date range,
  nickname, and text content.
  """

  @type t :: %__MODULE__{
          source: String.t() | nil,
          source_type: :channel | :pm,
          date_from: Date.t() | nil,
          date_to: Date.t() | nil,
          nickname: String.t() | nil,
          text: String.t() | nil,
          page: pos_integer(),
          per_page: pos_integer()
        }

  defstruct source: nil,
            source_type: :channel,
            date_from: nil,
            date_to: nil,
            nickname: nil,
            text: nil,
            page: 1,
            per_page: 50

  @fixed_per_page 50

  @doc """
  Creates a new LogFilter with default values.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a new LogFilter from a map of attributes.
  Unknown keys are ignored. The `per_page` field is always forced to #{@fixed_per_page}.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    allowed_keys = [:source, :source_type, :date_from, :date_to, :nickname, :text, :page]

    fields =
      attrs
      |> Map.take(allowed_keys)
      |> Map.to_list()

    struct(__MODULE__, fields)
  end

  @doc """
  Validates a LogFilter struct, returning `:ok` or `{:error, reason}`.

  Validation rules:
  - `date_from` must not be in the future
  - `date_to` must not be in the future
  - `date_from` must not be after `date_to` (when both are set)
  - `page` must be >= 1
  - `per_page` must be #{@fixed_per_page}
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = filter) do
    with :ok <- validate_page(filter.page),
         :ok <- validate_per_page(filter.per_page),
         :ok <- validate_date_not_future(:date_from, filter.date_from),
         :ok <- validate_date_not_future(:date_to, filter.date_to),
         :ok <- validate_date_range(filter.date_from, filter.date_to) do
      :ok
    end
  end

  @doc """
  Escapes regex and LIKE metacharacters in a text string for safe use
  in ILIKE queries. Escapes: `*`, `+`, `?`, `.`, `(`, `)`, `[`, `]`,
  `{`, `}`, `\\`, `^`, `$`, `|`, `%`, `_`.
  """
  @spec escape_text(String.t()) :: String.t()
  def escape_text(text) when is_binary(text) do
    String.replace(text, ~r/[*+?.()\[\]{}\\^$|%_]/, fn char -> "\\" <> char end)
  end

  # Private validation helpers

  defp validate_page(page) when is_integer(page) and page >= 1, do: :ok
  defp validate_page(_page), do: {:error, "page must be >= 1"}

  defp validate_per_page(@fixed_per_page), do: :ok
  defp validate_per_page(_per_page), do: {:error, "per_page must be #{@fixed_per_page}"}

  defp validate_date_not_future(_field, nil), do: :ok

  defp validate_date_not_future(field, %Date{} = date) do
    if Date.compare(date, Date.utc_today()) == :gt do
      {:error, "#{field} must not be in the future"}
    else
      :ok
    end
  end

  defp validate_date_range(nil, _date_to), do: :ok
  defp validate_date_range(_date_from, nil), do: :ok

  defp validate_date_range(%Date{} = from, %Date{} = to) do
    if Date.compare(from, to) == :gt do
      {:error, "date_from must not be after date_to"}
    else
      :ok
    end
  end
end
