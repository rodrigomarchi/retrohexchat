# Research: Log Viewer

**Feature Branch**: `008-log-viewer`
**Date**: 2026-02-11

## Decision 1: Message Query Strategy

**Decision**: Extend `Chat.Queries` with new offset-based paginated query functions that support date range, author, type, and text filters — compose a single Ecto query with optional `where` clauses.

**Rationale**: The existing `list_messages/2` uses cursor-based pagination (before_id) optimized for infinite scroll. The Log Viewer needs page-based navigation (page 2 of 15) which requires offset/limit and a total count. A new `search_log/2` function with composable filters is cleaner than modifying the existing functions.

**Alternatives considered**:
- Reuse existing `Chat.Search.search_messages/3` — too limited, only supports channel + text, no date/author/type filters.
- Raw SQL — violates Ecto conventions and harder to test.
- Full-text search with PostgreSQL tsvector — overkill for current scale; ILIKE is sufficient with existing indexes.

## Decision 2: Pagination Approach for Log Viewer

**Decision**: Use offset-based pagination with `OFFSET`/`LIMIT` and a separate `COUNT(*)` query for total pages. 50 messages per page.

**Rationale**: The Log Viewer needs "Page 2 of 15" display and Previous/Next navigation. Cursor-based pagination cannot provide total page counts. Offset pagination is acceptable here because: (a) users won't paginate through millions of rows — the filter narrows results first, (b) the existing index on `(channel_name, inserted_at DESC)` supports efficient offset queries for reasonable result sizes.

**Alternatives considered**:
- Cursor-based with estimated counts — complex UX, no "jump to page" ability.
- Load all results into memory — dangerous for large channels with months of history.
- Infinite scroll — inconsistent with the export-centric nature of log viewing.

## Decision 3: Export Download Mechanism

**Decision**: Use `push_event` from LiveView to a JS DownloadHook that creates a Blob and triggers browser download. Export content is built server-side and sent as a base64-encoded string.

**Rationale**: Consistent with existing push_event patterns (sound, link preview). No server-side file storage needed. Works for exports up to ~10MB which far exceeds typical log exports. For very large exports (500+ messages), use chunked assembly with progress tracking.

**Alternatives considered**:
- Dedicated Phoenix controller endpoint for download — adds routing complexity, breaks LiveView-only pattern.
- Server-side file generation with temporary storage — unnecessary infrastructure for transient exports.
- Streaming response — LiveView doesn't natively support streaming downloads.

## Decision 4: Guest User Session-Only Logs

**Decision**: Guest users' "history" comes from their LiveView socket's in-memory message stream. The Log Viewer queries the `chat_messages` stream data already held in assigns rather than the database.

**Rationale**: Guest users are not identified and have no persistent identity. Querying the database for "all messages from a guest" is meaningless since guest nicknames can collide across sessions. Using the in-memory stream (which already holds all messages seen during the session) is both correct and simple.

**Alternatives considered**:
- Query database by nickname + session start time — fragile, nickname collisions possible.
- Disable Log Viewer for guests entirely — spec explicitly requires guest access to session data.

## Decision 5: Display Preferences Storage

**Decision**: Store display preferences in the Session struct (in-memory, per-session). No database persistence for log preferences — they reset each session.

**Rationale**: The spec says "persist for the duration of the session." Session struct is the established pattern for in-memory per-user state (strip_formatting, highlight_words, etc.). No migration needed.

**Alternatives considered**:
- Database persistence — spec explicitly says session-only, would over-engineer.
- Browser localStorage via JS hook — breaks the LiveView-first principle.

## Decision 6: Private Message Log Access

**Decision**: Query `private_messages` table using the existing `LEAST/GREATEST` index pattern. The channel/PM dropdown groups channels and PMs separately. PM conversations are identified by the partner nickname.

**Rationale**: The existing `list_private_messages/3` uses efficient bidirectional lookup. The Log Viewer reuses this pattern with added date/text filter support.

**Alternatives considered**:
- Unified query across both tables — PostgreSQL UNION queries are less efficient and harder to type-filter.
- Separate log viewer tabs for channels vs PMs — unnecessary UI complexity.

## Decision 7: Channel/PM Dropdown Population

**Decision**: For registered users, query `DISTINCT channel_name FROM messages WHERE author_nickname = ?` UNION `DISTINCT LEAST/GREATEST pairs FROM private_messages WHERE sender/recipient = ?`. For guests, derive from `session.channels` and `session.pm_conversations`.

**Rationale**: This gives an accurate list of channels/PMs the user has participated in, including historical ones no longer active. Efficient with indexes.

**Alternatives considered**:
- Use only current session channels — would miss historical data.
- Hardcode #lobby — too limiting.
