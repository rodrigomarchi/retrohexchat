# Data Model: Log Viewer

**Feature Branch**: `008-log-viewer`
**Date**: 2026-02-11

## Existing Entities (No Changes)

### Message (table: `messages`)

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| id | integer | PK, auto | Sequential ID |
| channel_name | string(50) | NOT NULL | e.g., "#lobby" |
| author_nickname | string(16) | NOT NULL | e.g., "Alice" |
| content | text | NOT NULL | Message body (may contain format codes) |
| type | string(10) | NOT NULL, default "message" | "message", "action", "system", "service", "error" |
| inserted_at | utc_datetime_usec | NOT NULL | Timestamp |

**Indexes**: `(channel_name, inserted_at DESC)`

### PrivateMessage (table: `private_messages`)

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| id | integer | PK, auto | Sequential ID |
| sender_nickname | string(16) | NOT NULL | Sender |
| recipient_nickname | string(16) | NOT NULL | Recipient |
| content | text | NOT NULL | Message body |
| type | string(10) | NOT NULL, default "message" | "message", "action" |
| inserted_at | utc_datetime_usec | NOT NULL | Timestamp |

**Indexes**: `(recipient_nickname, inserted_at DESC)`, `(LEAST/GREATEST conversation, inserted_at DESC)`

## New Entities (In-Memory Only)

### LogFilter (pure struct, no database)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| source | string | nil | Channel name or PM partner; nil = all |
| source_type | atom | :channel | :channel or :pm |
| date_from | Date | nil | Start date filter (inclusive) |
| date_to | Date | nil | End date filter (inclusive) |
| nickname | string | nil | Author filter (case-insensitive partial match) |
| text | string | nil | Text search (literal, case-insensitive) |
| page | integer | 1 | Current page number |
| per_page | integer | 50 | Results per page |

**Validation Rules**:
- `date_from` must not be in the future
- `date_to` must not be in the future
- `date_from` must not be after `date_to` (when both set)
- `text` must have regex metacharacters escaped before query
- `page` must be >= 1
- `per_page` must be 50 (fixed)

### DisplayPreferences (pure struct, no database)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| show_joins | boolean | true | Toggle join events |
| show_parts | boolean | true | Toggle part events |
| show_kicks | boolean | true | Toggle kick events |
| show_mode_changes | boolean | true | Toggle mode change events |
| show_topic_changes | boolean | true | Toggle topic change events |
| timestamp_format | atom | :hh_mm_ss | One of :hh_mm, :hh_mm_ss, :dd_mm_hh_mm |

### LogPage (query result wrapper, no database)

| Field | Type | Notes |
|-------|------|-------|
| entries | list(Message.t or PrivateMessage.t) | Current page results |
| total_count | integer | Total matching messages |
| page | integer | Current page |
| total_pages | integer | Computed from total_count / per_page |
| filter | LogFilter.t | The filter that produced these results |

## Entity Relationships

```
LogFilter ──[queries]──→ Message (via channel_name)
LogFilter ──[queries]──→ PrivateMessage (via sender/recipient)
LogFilter + Messages ──→ LogPage (paginated result)
DisplayPreferences ──[applied to]──→ LogPage (client-side filtering of event types)
LogPage + DisplayPreferences ──[exported as]──→ .txt or .html file
```

## No New Migrations Required

This feature reads from existing `messages` and `private_messages` tables. All new data structures are in-memory only. The only potential database change is an optional index for text search performance, which can be evaluated during implementation.

**Potential index addition** (if performance testing warrants):
- `CREATE INDEX idx_messages_content_trigram ON messages USING gin (content gin_trgm_ops)` — for faster `ILIKE` text search
- This is an optimization, not a requirement for correctness
