# Contract: CapturedURL Struct

**Module**: `RetroHexChat.Chat.CapturedURL`
**Layer**: Domain (`retro_hex_chat`)
**Persistence**: None (in-memory only)

## Struct Definition

```elixir
@type t :: %__MODULE__{
  id: String.t(),
  url: String.t(),
  source: String.t(),
  source_type: :channel | :pm,
  posted_by: String.t(),
  timestamp: DateTime.t(),
  preview_title: String.t() | nil
}
```

## Public API

### `new/1`

Creates a new CapturedURL from message data.

```elixir
@spec new(map()) :: t()
```

**Input**: Map with keys `:url`, `:source`, `:source_type`, `:posted_by`, `:timestamp`.
**Output**: `%CapturedURL{}` with auto-generated `id` and `preview_title: nil`.

### `set_preview_title/2`

Updates the preview title for a captured URL entry.

```elixir
@spec set_preview_title(t(), String.t() | nil) :: t()
```

## Filtering & Sorting (Utility Functions)

### `filter_by_source/2`

```elixir
@spec filter_by_source(list(t()), String.t() | nil) :: list(t())
```

Filters entries by source (channel name or PM nick). `nil` returns all entries.

### `filter_by_url/2`

```elixir
@spec filter_by_url(list(t()), String.t()) :: list(t())
```

Filters entries whose URL contains the search string (case-insensitive).

### `sort_by/3`

```elixir
@spec sort_by(list(t()), atom(), :asc | :desc) :: list(t())
```

Sorts entries by the given field (`:url`, `:source`, `:posted_by`, `:timestamp`).
