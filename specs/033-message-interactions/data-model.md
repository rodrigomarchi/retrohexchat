# Data Model: Quote/Reply & Message Edit/Delete

**Feature Branch**: `033-message-interactions`
**Date**: 2026-02-16

## Entity Changes

### Message (extended)

Existing fields preserved. New fields added:

| Field | Type | Nullable | Default | Description |
|-------|------|----------|---------|-------------|
| `reply_to_id` | `bigint` (self-referential FK, ON DELETE SET NULL) | Yes | `nil` | ID of the parent message being replied to. If parent is hard-deleted, becomes NULL. |
| `reply_to_author` | `string` (max 16) | Yes | `nil` | Denormalized parent message author. Actively updated when parent is edited. |
| `reply_to_preview` | `string` (max 100) | Yes | `nil` | Denormalized parent message content, truncated to 100 chars. Actively updated when parent is edited (FR-022). |
| `edited_at` | `utc_datetime_usec` | Yes | `nil` | Timestamp of last edit; `nil` = never edited |
| `deleted_at` | `utc_datetime_usec` | Yes | `nil` | Timestamp of soft delete; `nil` = not deleted |

**Validation rules**:
- `reply_to_id` must reference an existing message in the same channel (or `nil`)
- `reply_to_author` and `reply_to_preview` must both be present if `reply_to_id` is set
- `edited_at` is set server-side only, never from user input
- `deleted_at` is set server-side only, never from user input
- A deleted message (`deleted_at != nil`) cannot be edited
- An already-deleted message cannot be deleted again

**Backward compatibility**: Existing messages (pre-deployment) have `nil` for all new fields. They render normally — no reply block, no "(editado)" tag, no deleted state.

**Indexes**:
- `idx_messages_reply_to_id` on `(reply_to_id)` — for finding replies to a message (updating quotes on edit)

**Migration performance**: All new columns are nullable with no default values. PostgreSQL adds nullable columns without rewriting existing rows, so this migration is lightweight even on large tables.

### PrivateMessage (extended)

Same new fields as Message:

| Field | Type | Nullable | Default | Description |
|-------|------|----------|---------|-------------|
| `reply_to_id` | `bigint` (self-referential FK, ON DELETE SET NULL) | Yes | `nil` | ID of the parent PM being replied to |
| `reply_to_author` | `string` (max 16) | Yes | `nil` | Denormalized parent PM author |
| `reply_to_preview` | `string` (max 100) | Yes | `nil` | Denormalized parent PM content, truncated to 100 chars |
| `edited_at` | `utc_datetime_usec` | Yes | `nil` | Timestamp of last edit |
| `deleted_at` | `utc_datetime_usec` | Yes | `nil` | Timestamp of soft delete |

**Indexes**:
- `idx_private_messages_reply_to_id` on `(reply_to_id)`

## State Transitions

### Message Lifecycle

```
[Created] → content set, reply fields set (if reply), edited_at=nil, deleted_at=nil
    │
    ├─ [Edited] → content updated, edited_at set, reply_to_preview updated in child messages
    │      │       (within 5-min window, or grace period of +2 min if edit started in time)
    │      │       (3-second debounce between successive edits)
    │      │
    │      └─ [Edited again] → content updated, edited_at updated
    │
    └─ [Deleted] → deleted_at set, content preserved in DB but hidden in UI
         │         (within 5-min window, NO grace period)
         │
         └─ (terminal — no further transitions)
```

### Edit Mode (Client State)

```
[Normal] ── ↑ key (input empty + last msg is most recent + within 5 min) ──→ [Edit Mode]
    ↑                                                                              │
    │    ┌── Reply trigger cancels edit ───────────────────────────────────────────┘│
    │    │                                                                         │
    │    ├── Enter → submit edit → [Normal]                                        │
    │    ├── Escape → cancel → [Normal]                                            │
    │    ├── Empty submit → [Delete Confirmation Dialog]                           │
    │    └── Channel switch → cancel → [Normal]                                    │
    └──────────────────────────────────────────────────────────────────────────────┘
```

### Reply Mode (Client State)

```
[Normal] ── context menu "Responder" / hover button ──→ [Reply Mode]
    ↑                                                         │
    │    ┌── Edit trigger (↑) cancels reply ──────────────────┘│
    │    │                                                     │
    │    ├── Enter → send with reply_to → [Normal]             │
    │    ├── "✕" button / Escape → cancel → [Normal]           │
    │    └── Channel switch → cancel → [Normal]                │
    └──────────────────────────────────────────────────────────┘
```

## PubSub Event Payloads

### message_edited

```
Topic: "channel:#{channel_name}" or "pm:#{sorted_nicks}"
Event: "message_edited"
Payload:
  id: integer          # message ID
  content: string      # new content (HTML-safe)
  edited_at: datetime  # edit timestamp
```

### message_deleted

```
Topic: "channel:#{channel_name}" or "pm:#{sorted_nicks}"
Event: "message_deleted"
Payload:
  id: integer          # message ID
  deleted_at: datetime # deletion timestamp
```

### reply_quote_updated

```
Topic: "channel:#{channel_name}" or "pm:#{sorted_nicks}"
Event: "reply_quote_updated"
Payload:
  parent_id: integer        # edited parent message ID
  new_preview: string       # updated truncated content (max 100 chars)
  reply_ids: [integer]      # IDs of messages that reply to this parent
```

## Migration Plan

Single migration file adding all new columns to both tables:

1. `ALTER TABLE messages ADD COLUMN reply_to_id BIGINT REFERENCES messages(id) ON DELETE SET NULL`
2. `ALTER TABLE messages ADD COLUMN reply_to_author VARCHAR(16)`
3. `ALTER TABLE messages ADD COLUMN reply_to_preview VARCHAR(100)`
4. `ALTER TABLE messages ADD COLUMN edited_at TIMESTAMPTZ`
5. `ALTER TABLE messages ADD COLUMN deleted_at TIMESTAMPTZ`
6. `CREATE INDEX idx_messages_reply_to_id ON messages(reply_to_id)`
7. Same 6 operations for `private_messages` (self-referential FK to `private_messages(id)`)

**Note**: ON DELETE SET NULL on reply_to_id means if a message row is hard-deleted by a DB admin, reply references become NULL and display "Respondendo a [mensagem removida]" — same behavior as soft-delete.
