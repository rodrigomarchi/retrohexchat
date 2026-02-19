# Data Model: Session Persistence

## No New Tables or Migrations

This feature operates entirely on existing data structures. No schema changes needed.

## Existing Entities Used

### private_messages (existing table)

| Column | Type | Notes |
|--------|------|-------|
| id | bigint | PK, auto-increment |
| sender_nickname | varchar(16) | NOT NULL |
| recipient_nickname | varchar(16) | NOT NULL |
| content | text | |
| type | varchar | "message", "action", "p2p_invite" |
| inserted_at | utc_datetime_usec | |

**Relevant indexes**:
- `idx_pm_conversation`: `(LEAST(sender_nickname, recipient_nickname), GREATEST(sender_nickname, recipient_nickname), inserted_at DESC)`
- `idx_pm_recipient`: `(recipient_nickname, inserted_at)`

### autojoin_list_entries (existing table)

| Column | Type | Notes |
|--------|------|-------|
| id | bigint | PK |
| owner_nickname | varchar(16) | NOT NULL |
| channel_name | varchar(50) | NOT NULL, starts with "#" |
| channel_key | varchar(50) | Nullable |
| position | integer | Sort order |

**Constraints**: Unique on `(owner_nickname, channel_name)`. Max 20 entries per owner (enforced in application).

## New Query: list_pm_partners/2

```
list_pm_partners(nickname, opts \\ [])
  Input:  nickname (string), opts (keyword list with :limit, default 50)
  Output: [%{nickname: String.t(), last_message_at: DateTime.t()}]

  Logic:
    1. SELECT DISTINCT partner nicknames from private_messages where
       sender_nickname = nickname OR recipient_nickname = nickname
    2. For each partner, compute MAX(inserted_at) as last_message_at
    3. Exclude the user's own nickname (self-PMs)
    4. Exclude soft-deleted messages (deleted_at IS NULL)
    5. ORDER BY last_message_at DESC
    6. LIMIT opts[:limit] (default 50)
```

## In-Memory State Changes

### Session.pm_conversations

**Current**: `[String.t()]` — unordered list of nicknames, appended on add.

**New behavior**: `[String.t()]` — recency-ordered list of nicknames. Most recent conversation is at the head (index 0). On add/activity, the nick moves to head position. On restore, the query returns nicks in recency order.

### Modified functions:

- `Session.add_pm_conversation/2`: Changed from append-to-end to prepend-to-head. If nick already exists, moves it to head.
- `Session.move_pm_to_front/2` (new): Moves an existing nick to the head of pm_conversations. No-op if nick not found.

### No changes to:

- `Session.remove_pm_conversation/2`: Works the same (removes by value).
- `Session.set_active_pm/2`: Works the same.
- `UnreadTracker`: No changes — keying by `"pm:#{nick}"` continues to work.
- `AutoJoinList` module: No structural changes. Existing CRUD API is sufficient.
