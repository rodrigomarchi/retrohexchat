# Domain API Contract: Log Viewer

## Module: `RetroHexChat.Chat.LogFilter`

Pure struct + validation for log search criteria.

```elixir
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

@spec new() :: t()
@spec new(map()) :: t()

@spec validate(t()) :: :ok | {:error, String.t()}
# Validates: no future dates, date_from <= date_to, page >= 1

@spec escape_text(String.t()) :: String.t()
# Escapes regex metacharacters for literal ILIKE matching
```

## Module: `RetroHexChat.Chat.DisplayPreferences`

Pure struct for log display configuration.

```elixir
@type timestamp_format :: :hh_mm | :hh_mm_ss | :dd_mm_hh_mm

@type t :: %__MODULE__{
  show_joins: boolean(),
  show_parts: boolean(),
  show_kicks: boolean(),
  show_mode_changes: boolean(),
  show_topic_changes: boolean(),
  timestamp_format: timestamp_format()
}

@spec new() :: t()
# Defaults: all true, :hh_mm_ss

@spec toggle_event(t(), atom()) :: t()
# Toggles a specific event type (e.g., :show_joins)

@spec set_timestamp_format(t(), timestamp_format()) :: t()

@spec format_timestamp(t(), DateTime.t()) :: String.t()
# Returns formatted timestamp string based on selected format

@spec visible_type?(t(), String.t()) :: boolean()
# Returns true if the given message type should be shown
# "message" and "action" are always visible
# "system" events are checked against individual toggles based on content
```

## Module: `RetroHexChat.Chat.LogPage`

Pagination result wrapper.

```elixir
@type t :: %__MODULE__{
  entries: [Message.t() | PrivateMessage.t()],
  total_count: non_neg_integer(),
  page: pos_integer(),
  total_pages: non_neg_integer(),
  filter: LogFilter.t()
}

@spec new(list(), non_neg_integer(), LogFilter.t()) :: t()
# Computes total_pages from total_count and filter.per_page
```

## Module: `RetroHexChat.Chat.LogQueries`

Database query functions for log viewer. Extends Chat context.

```elixir
@spec search_channel_log(LogFilter.t()) :: LogPage.t()
# Queries `messages` table with all filter criteria applied
# Returns paginated results in chronological order (oldest first)

@spec search_pm_log(String.t(), LogFilter.t()) :: LogPage.t()
# Queries `private_messages` table for a specific conversation
# `nickname` param is the current user's nick for bidirectional lookup

@spec count_channel_log(LogFilter.t()) :: non_neg_integer()
# Returns total count for channel log filter (for pagination)

@spec count_pm_log(String.t(), LogFilter.t()) :: non_neg_integer()
# Returns total count for PM log filter

@spec list_user_channels(String.t()) :: [String.t()]
# Returns DISTINCT channel_name from messages WHERE author_nickname = ?
# Sorted alphabetically

@spec list_user_pm_partners(String.t()) :: [String.t()]
# Returns DISTINCT partner nicknames from private_messages
# WHERE sender_nickname = ? OR recipient_nickname = ?
# Sorted alphabetically
```

## Module: `RetroHexChat.Chat.LogExporter`

Export log entries to downloadable formats.

```elixir
@type export_format :: :txt | :html

@spec export(list(), DisplayPreferences.t(), export_format()) :: String.t()
# Takes a list of messages, applies display preferences (filter events, format timestamps),
# produces formatted string content

@spec export_txt(list(), DisplayPreferences.t()) :: String.t()
# Format: [HH:MM:SS] <NickName> message content
# System events: [HH:MM:SS] * event description
# One message per line

@spec export_html(list(), DisplayPreferences.t()) :: String.t()
# Produces standalone HTML document with embedded CSS matching chat style
# Uses Formatter.to_safe_html/2 for formatted message content
# Includes IRC color classes and dark theme styling

@spec generate_filename(LogFilter.t(), export_format()) :: String.t()
# Returns filename like "project_2026-02-05_to_2026-02-11.txt"
# Strips # from channel names
```

## Session Extension

```elixir
# In RetroHexChat.Accounts.Session:

@spec set_log_preferences(t(), DisplayPreferences.t()) :: t()
@spec log_preferences(t()) :: DisplayPreferences.t()
# Getter/setter for display preferences, stored in session struct
```
