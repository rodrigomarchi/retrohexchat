# Data Model: User Information

## Entity: User Bio

**Storage**: PostgreSQL (`user_bios` table)
**Persistence**: Single row per registered user, delete-and-reinsert on update

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| owner_nickname | string(16) | FK → registered_nicks.nickname, PK, NOT NULL, ON DELETE CASCADE | Owner's registered nickname |
| bio_text | string(200) | NOT NULL | User's bio text (max 200 Unicode graphemes) |
| inserted_at | utc_datetime_usec | auto | Creation timestamp |
| updated_at | utc_datetime_usec | auto | Last update timestamp |

### Indexes

- Primary key on `owner_nickname`

### Validation Rules

- `bio_text` max 200 Unicode graphemes (enforced at domain level before persistence)
- `owner_nickname` must reference an existing registered nick

---

## Entity: Whowas Entry (In-Memory)

**Storage**: ETS table (`:whowas_cache`)
**Persistence**: None — ephemeral, expires after 1 hour, lost on restart

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| nickname | string | Key (case-insensitive lookup) | Disconnected user's nickname |
| channels | list(string) | Required | Channels user was in at disconnect |
| quit_message | string | nullable | Quit/disconnect reason message |
| disconnected_at | DateTime | Required | When the user disconnected |

### Lifecycle

- **Created**: When a user disconnects (ChatLive terminate callback)
- **Read**: When `/whowas <nickname>` is executed
- **Updated**: If same nickname disconnects again, entry is overwritten
- **Deleted**: After 1 hour (TTL expiry) or when cache exceeds 1000 entries (oldest evicted)

### Cache Rules

- Maximum 1000 entries
- TTL: 3600 seconds (1 hour)
- Periodic cleanup every 10 minutes
- On insert at capacity: evict oldest entry by `disconnected_at`
- Lookup is case-insensitive

---

## Entity: Idle Tracking (In-Memory)

**Storage**: Phoenix Presence metadata + socket assigns
**Persistence**: None — ephemeral, per-connection

### Fields

| Field | Type | Description |
|-------|------|-------------|
| last_activity_at | DateTime | Timestamp of user's last activity (message, PM, command) |
| connected_at | DateTime | Already exists in Session struct — session start time |

### Lifecycle

- **Set on connect**: `last_activity_at` initialized to `DateTime.utc_now()`
- **Updated**: On every user activity (channel message, PM, command)
- **Read**: When `/whois` queries the user's idle time via Presence metadata
- **Deleted**: When user disconnects (socket terminates)

### Idle Time Calculation

```
idle_seconds = DateTime.diff(DateTime.utc_now(), last_activity_at, :second)
```

---

## Entity: User Bio (In-Memory / Session)

**Storage**: Session struct field
**Persistence**: Loaded from DB on NickServ identification

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| bio | string | nil | User's current bio text, nil if unset |

### Session Integration

- Added to Session struct as `bio: String.t() | nil`
- Getter: `Session.get_bio/1`
- Setter: `Session.set_bio/2`
- Loaded via `load_persisted_data` chain: `UserBio.load(nick)` → `Session.set_bio/2`

---

## Relationships

```
registered_nicks (existing)
  └── user_bios (1:0..1) — one bio per registered user

Session (in-memory)
  ├── bio (string | nil) — loaded from user_bios on identification
  ├── connected_at (DateTime) — already exists
  └── channels ([string]) — already exists, used for shared channel computation

Presence metadata (per user per topic)
  └── last_activity_at (DateTime) — added for idle tracking

WhowasCache (ETS)
  └── {nickname, entry} — keyed by lowercase nickname
```
