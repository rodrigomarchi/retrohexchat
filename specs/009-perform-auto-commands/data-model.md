# Data Model: Perform / Auto-Commands

**Branch**: `009-perform-auto-commands` | **Date**: 2026-02-12

## Entities

### PerformEntry (Domain Struct)

In-memory representation of a single perform command.

| Field    | Type              | Constraints                   | Description                      |
|----------|-------------------|-------------------------------|----------------------------------|
| command  | String.t()        | Required, 1-500 chars         | Full slash command (e.g., "/join #elixir") |
| position | non_neg_integer() | Required, unique within owner | Execution order (0-indexed)      |

**Validation rules**:
- Command must start with `/`
- Command must not be a disallowed command (`/quit`, `/perform`, `/autojoin`, `/disconnect`)
- Maximum 50 entries per user
- Command length: 1-500 characters

---

### AutoJoinEntry (Domain Struct)

In-memory representation of a channel to auto-join.

| Field        | Type              | Constraints                    | Description                      |
|--------------|-------------------|--------------------------------|----------------------------------|
| channel_name | String.t()        | Required, starts with `#`, 2-50 chars | Channel to auto-join       |
| channel_key  | String.t() \| nil | Optional, max 50 chars         | Key for +k channels             |
| position     | non_neg_integer() | Required, unique within owner  | Join order (0-indexed)          |

**Validation rules**:
- Channel name must start with `#`
- Channel name must not contain spaces
- No duplicate channel names per user (case-insensitive)
- Maximum 20 entries per user

---

### PerformList (In-Memory Aggregate)

Wraps the list of PerformEntry structs with settings.

```
%{
  entries: [PerformEntry.t()],
  settings: %{
    enable_on_connect: boolean()  # default: true
  }
}
```

---

### AutoJoinList (In-Memory Aggregate)

Wraps the list of AutoJoinEntry structs.

```
%{
  entries: [AutoJoinEntry.t()]
}
```

---

### ReconnectionState (Client-Side / localStorage)

Temporary state saved by the ReconnectHook for session restoration.

```json
{
  "nickname": "Alice",
  "channels": ["#lobby", "#elixir", "#phoenix"],
  "active_channel": "#elixir",
  "active_pm": null,
  "perform_list": [
    {"command": "/ns identify ****", "position": 0},
    {"command": "/join #elixir", "position": 1}
  ],
  "autojoin_list": [
    {"channel_name": "#phoenix", "channel_key": null, "position": 0}
  ],
  "enable_on_connect": true,
  "timestamp": 1707696000000,
  "intentional_disconnect": false
}
```

---

## Database Tables

### perform_entries

| Column         | Type                    | Nullable | Default   | Notes                                    |
|----------------|-------------------------|----------|-----------|------------------------------------------|
| id             | BIGSERIAL               | NOT NULL | auto      | Primary key                              |
| owner_nickname | VARCHAR(16)             | NOT NULL |           | FK → registered_nicks(nickname) CASCADE  |
| command        | TEXT                    | NOT NULL |           | Full slash command text                  |
| position       | INTEGER                 | NOT NULL | 0         | Execution order                          |
| inserted_at    | TIMESTAMPTZ (usec)      | NOT NULL |           |                                          |
| updated_at     | TIMESTAMPTZ (usec)      | NOT NULL |           |                                          |

**Indexes**:
- `idx_perform_entries_owner` on `(owner_nickname)`
- `idx_perform_entries_owner_position` unique on `(owner_nickname, position)`

**Constraints**:
- `command_length` CHECK: `char_length(command) >= 1 AND char_length(command) <= 500`

---

### autojoin_entries

| Column         | Type                    | Nullable | Default   | Notes                                    |
|----------------|-------------------------|----------|-----------|------------------------------------------|
| id             | BIGSERIAL               | NOT NULL | auto      | Primary key                              |
| owner_nickname | VARCHAR(16)             | NOT NULL |           | FK → registered_nicks(nickname) CASCADE  |
| channel_name   | VARCHAR(50)             | NOT NULL |           | Channel name (e.g., "#elixir")           |
| channel_key    | VARCHAR(50)             | YES      |           | Optional key for +k channels             |
| position       | INTEGER                 | NOT NULL | 0         | Join order                               |
| inserted_at    | TIMESTAMPTZ (usec)      | NOT NULL |           |                                          |
| updated_at     | TIMESTAMPTZ (usec)      | NOT NULL |           |                                          |

**Indexes**:
- `idx_autojoin_entries_owner` on `(owner_nickname)`
- `idx_autojoin_entries_owner_channel` unique on `(lower(owner_nickname), lower(channel_name))`

---

### perform_settings

| Column            | Type                    | Nullable | Default   | Notes                                    |
|-------------------|-------------------------|----------|-----------|------------------------------------------|
| owner_nickname    | VARCHAR(16)             | NOT NULL |           | PK, FK → registered_nicks(nickname) CASCADE |
| enable_on_connect | BOOLEAN                 | NOT NULL | true      | Global toggle for perform execution      |
| inserted_at       | TIMESTAMPTZ (usec)      | NOT NULL |           |                                          |
| updated_at        | TIMESTAMPTZ (usec)      | NOT NULL |           |                                          |

**Primary key**: `owner_nickname`

---

## Entity Relationships

```
registered_nicks (nickname PK)
  ├── perform_entries (owner_nickname FK, CASCADE)
  ├── autojoin_entries (owner_nickname FK, CASCADE)
  └── perform_settings (owner_nickname FK+PK, CASCADE)
```

All tables cascade on delete — when a registered nick is removed, all perform/autojoin data is deleted automatically.

---

## State Transitions

### Perform List Lifecycle

```
Empty → [add_entry] → Has Entries → [add_entry] → Has Entries (up to 50)
Has Entries → [remove_entry] → Has Entries or Empty
Has Entries → [move_entry] → Has Entries (reordered)
Has Entries → [clear] → Empty
Any State → [set_enabled(false)] → Disabled (entries preserved, not executed)
```

### Session Data Flow

```
Mount (cold start)
  → Check localStorage for saved state
  → If found: load perform_list + autojoin_list from localStorage
  → Execute perform commands (if enabled)
  → Execute autojoin channels
  → If not found: no auto-execution, user starts fresh

Identification
  → load_persisted_data loads perform_list + autojoin_list from DB
  → Overwrites in-memory data with authoritative DB data
  → Saves updated data to localStorage

Modification (add/remove/move/clear)
  → Update in-memory Session
  → maybe_persist (async Task, only if identified)
  → push_event to save to localStorage

Reconnect
  → localStorage has state from before disconnect
  → Mount detects reconnect flag
  → Execute perform + autojoin + rejoin previous channels
```
