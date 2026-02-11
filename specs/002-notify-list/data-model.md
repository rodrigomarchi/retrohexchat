# Data Model: Notify List (Buddy List)

**Feature**: 002-notify-list
**Date**: 2026-02-11

## Entities

### notify_list_entries (PostgreSQL table — persistent storage for registered users)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigserial | PK | Auto-incrementing primary key |
| owner_nickname | varchar(16) | NOT NULL, FK → registered_nicks(nickname) ON DELETE CASCADE | The registered user who owns this entry |
| tracked_nickname | varchar(16) | NOT NULL | The buddy being tracked (may not exist as a registered nick) |
| note | varchar(200) | nullable, default NULL | Personal note about the buddy |
| last_seen_at | utc_datetime_usec | nullable, default NULL | Last time the buddy was seen going offline |
| inserted_at | utc_datetime_usec | NOT NULL | Creation timestamp |
| updated_at | utc_datetime_usec | NOT NULL | Last update timestamp |

**Indexes**:
- `UNIQUE (owner_nickname, tracked_nickname)` — one entry per buddy per owner (case-insensitive via `lower()`)
- `INDEX (owner_nickname)` — fast load of all entries for a user

**Constraints**:
- `owner_nickname` references `registered_nicks(nickname)` with `ON DELETE CASCADE` — if a user drops their registration, their notify list is cleaned up.
- No FK on `tracked_nickname` — buddies may be unregistered nicknames or not yet connected.
- Maximum 50 entries per owner enforced at application level (not DB constraint).

### notify_list_settings (PostgreSQL table — per-user global settings)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| owner_nickname | varchar(16) | PK, FK → registered_nicks(nickname) ON DELETE CASCADE | The registered user |
| auto_whois | boolean | NOT NULL, default false | Global auto-whois toggle |
| inserted_at | utc_datetime_usec | NOT NULL | Creation timestamp |
| updated_at | utc_datetime_usec | NOT NULL | Last update timestamp |

**Design decision**: Separate table for settings to avoid adding columns to `registered_nicks`. Settings are loaded alongside entries on identify.

### NotifyEntry (in-memory struct — runtime representation)

```elixir
%NotifyEntry{
  tracked_nickname: String.t(),    # The buddy's current nickname
  note: String.t() | nil,         # Personal note (max 200 chars)
  last_seen_at: DateTime.t() | nil, # Last offline timestamp
  online: boolean()                # Current online status (computed at runtime, not persisted)
}
```

**Not persisted**: `online` is a runtime-only field computed from global presence events. It is not stored in the database.

## State Transitions

### Notify List Entry Lifecycle

```
                 add_buddy()
    (none) ────────────────────► OFFLINE (default)
                                    │
                   buddy_connected  │  buddy_disconnected
                    ┌───────────────┼──────────────────┐
                    │               │                   │
                    ▼               │                   ▼
                  ONLINE ◄──────────┘              OFFLINE
                    │               │           (last_seen updated)
                    │               │
                    └───────────────┘
                                    │
                  remove_buddy()    │
                    ────────────────►  (none)
```

### Buddy Rename Flow

```
  :nick_changed received
        │
        ▼
  Is old_nick in notify list?
        │
    Yes ─┤─ No → ignore
        │
        ▼
  Update entry: tracked_nickname = new_nick
  Persist to DB (if registered owner)
  Display rename message in Status window
```

### Debounce State Machine (per buddy, per LiveView)

```
  IDLE ──── buddy_event ────► PENDING
              │                   │
              │              10s timer
              │                   │
              │                   ▼
              │               EMIT notification
              │               → back to IDLE
              │
              │  opposite event within 10s
              │                   │
              │                   ▼
              │            CANCEL timer
              │            Start new timer for final state
              │            → PENDING (with new state)
```

## Relationships

```
registered_nicks (1) ──── owns ────► (0..50) notify_list_entries
registered_nicks (1) ──── has ─────► (0..1)  notify_list_settings

notify_list_entries.tracked_nickname ──── (no FK) ────► any nickname (may not exist)
```

## Data Volume Assumptions

- Max 50 entries per user (application-enforced).
- Settings table: 1 row per registered user who uses the feature.
- For 1000 registered users, worst case: 50,000 entries + 1,000 settings rows. Well within PostgreSQL's comfort zone.
