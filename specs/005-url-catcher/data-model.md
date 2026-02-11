# Data Model: URL Catcher (005)

**Branch**: `005-url-catcher` | **Date**: 2026-02-11

## Overview

This feature is entirely in-memory — no database migrations are needed. All data structures exist only for the duration of a user's session and are discarded on disconnect.

## Entities

### CapturedURL (In-Memory Struct)

Represents a single URL occurrence captured from a chat message during the current session.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String.t()` | Unique identifier for LiveView stream (auto-generated UUID) |
| `url` | `String.t()` | The full URL as detected in the message |
| `source` | `String.t()` | Channel name (e.g., `"#elixir"`) or PM nickname |
| `source_type` | `:channel \| :pm` | Whether the URL came from a channel or PM |
| `posted_by` | `String.t()` | Nickname of the user who sent the message |
| `timestamp` | `DateTime.t()` | When the message was received |
| `preview_title` | `String.t() \| nil` | Page title fetched asynchronously (nil until fetched) |

**Constraints**:
- `url` must start with `http://` or `https://`
- `source` must be a valid channel name (starting with `#`) or a nickname
- `posted_by` must be a non-empty string
- `preview_title` is HTML-escaped plain text (no raw HTML from external pages)

### URLMatch (Internal, URL Detection)

Represents a URL found within a text string. Used internally by URLDetector.

| Field | Type | Description |
|-------|------|-------------|
| `url` | `String.t()` | The detected URL string |
| `start` | `non_neg_integer()` | Start position in the original text |
| `length` | `non_neg_integer()` | Length of the URL in the original text |

### LinkPreviewCache Entry (ETS, In-Memory)

Cached page title for a URL. Stored in an ETS table.

| Field | Type | Description |
|-------|------|-------------|
| `url` | `String.t()` | The URL (ETS key) |
| `title` | `String.t() \| nil` | Fetched page title (nil means "no title found") |
| `fetched_at` | `integer()` | System monotonic time when the title was fetched |
| `status` | `:ok \| :error \| :pending` | Fetch result status |

**TTL**: 1 hour (3600 seconds). Entries older than TTL are treated as stale and re-fetched.

## State Locations

| Data | Location | Lifetime | Constitution Principle |
|------|----------|----------|----------------------|
| URL catcher entries | Socket assigns (`@url_catcher_entries`) | LiveView process | IX (hot data in memory) |
| Link preview cache | ETS table (`Chat.LinkPreview.Cache`) | Application lifetime | IX (hot data in ETS) |
| URL catcher UI state | Socket assigns (`@show_url_catcher`, `@url_catcher_sort_*`, `@url_catcher_filter_*`) | LiveView process | VII (thin LiveViews) |

## Relationships

```text
ChatMessage (existing)
  └─ contains 0..N URLs (extracted by URLDetector)
       └─ each URL becomes a CapturedURL in the session's url_catcher_entries
       └─ each URL may have a cached LinkPreview title

CapturedURL
  ├─ source → Channel name or PM nickname (existing entities)
  ├─ posted_by → User nickname (existing entity)
  └─ preview_title → from LinkPreviewCache (async)
```

## No Migrations Required

This feature introduces no database tables or columns. All data is transient and in-memory:
- `CapturedURL` structs in socket assigns
- `LinkPreviewCache` entries in ETS
- URL detection is a pure function with no state
