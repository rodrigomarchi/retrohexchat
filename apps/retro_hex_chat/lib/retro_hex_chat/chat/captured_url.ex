defmodule RetroHexChat.Chat.CapturedURL do
  @moduledoc """
  In-memory struct representing a URL captured from a chat message.
  Used by the URL Catcher window to display and manage captured URLs.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          url: String.t(),
          source: String.t(),
          source_type: :channel | :pm,
          posted_by: String.t(),
          timestamp: DateTime.t(),
          preview_title: String.t() | nil
        }

  @enforce_keys [:id, :url, :source, :source_type, :posted_by, :timestamp]
  defstruct [:id, :url, :source, :source_type, :posted_by, :timestamp, :preview_title]

  @spec new(map()) :: t()
  def new(attrs) do
    %__MODULE__{
      id: "url-#{System.unique_integer([:positive, :monotonic])}",
      url: attrs.url,
      source: attrs.source,
      source_type: attrs.source_type,
      posted_by: attrs.posted_by,
      timestamp: attrs.timestamp,
      preview_title: nil
    }
  end

  @spec set_preview_title(t(), String.t() | nil) :: t()
  def set_preview_title(%__MODULE__{} = entry, title) do
    %{entry | preview_title: title}
  end

  @spec filter_by_source(list(t()), String.t() | nil) :: list(t())
  def filter_by_source(entries, nil), do: entries

  def filter_by_source(entries, source) do
    Enum.filter(entries, &(&1.source == source))
  end

  @spec filter_by_url(list(t()), String.t()) :: list(t())
  def filter_by_url(entries, ""), do: entries

  def filter_by_url(entries, query) do
    downcased = String.downcase(query)
    Enum.filter(entries, &(String.downcase(&1.url) =~ downcased))
  end

  @spec sort_by(list(t()), atom(), :asc | :desc) :: list(t())
  def sort_by(entries, :timestamp, direction) do
    sorter = if direction == :asc, do: {:asc, DateTime}, else: {:desc, DateTime}
    Enum.sort_by(entries, & &1.timestamp, sorter)
  end

  def sort_by(entries, field, direction) when field in [:url, :source, :posted_by] do
    Enum.sort_by(entries, &Map.get(&1, field), direction)
  end
end
