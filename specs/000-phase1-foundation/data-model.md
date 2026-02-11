# Data Model: RetroHexChat Phase 1

**Date**: 2026-02-09
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

RetroHexChat uses a hot/cold data separation model (Constitution IX):

- **Hot data** (in-memory): Active channel state (GenServer), channel
  membership, user presence (Phoenix Presence), rate limit counters
  (ETS), NickServ identify timers.
- **Cold data** (PostgreSQL): Messages, private messages, registered
  nicks, registered channels, access list entries, bans (for registered
  channels).

## PostgreSQL Entities

### 1. messages

Stores all channel messages (user messages, actions, system events,
service messages).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | bigserial | PK | Auto-increment |
| channel_name | varchar(50) | NOT NULL, indexed | Channel this message belongs to |
| author_nickname | varchar(16) | NOT NULL | Sender's nickname at time of send |
| content | text | NOT NULL | Message body (max 1000 chars for user content, unconstrained for system) |
| type | varchar(10) | NOT NULL, default "message" | Enum: message, action, system, service, error |
| inserted_at | timestamptz | NOT NULL, default now() | When the message was created |

**Indexes**:
- `idx_messages_channel_inserted_at` — Composite on `(channel_name, inserted_at DESC)` for cursor-based pagination
- `idx_messages_content_trgm` — GIN trigram index on `content` for text search

**Notes**:
- No foreign key to a users table (users are ephemeral sessions in Phase 1)
- No foreign key to a channels table (channels are dynamic)
- `channel_name` is the canonical identifier (includes `#` prefix)
- System messages (join, part, quit, kick, ban, mode change, nick change, topic change) are persisted with type "system"

### 2. private_messages

Stores bidirectional private messages.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | bigserial | PK | Auto-increment |
| sender_nickname | varchar(16) | NOT NULL | Sender's nickname at time of send |
| recipient_nickname | varchar(16) | NOT NULL | Recipient's nickname |
| content | text | NOT NULL | Message body (max 1000 chars) |
| type | varchar(10) | NOT NULL, default "message" | Enum: message, action |
| inserted_at | timestamptz | NOT NULL, default now() | When the message was created |

**Indexes**:
- `idx_pm_conversation` — Composite on `(least(sender_nickname, recipient_nickname), greatest(sender_nickname, recipient_nickname), inserted_at DESC)` for cursor pagination of a conversation between two users
- `idx_pm_recipient` — On `(recipient_nickname, inserted_at DESC)` for finding unread PMs
- `idx_pm_content_trgm` — GIN trigram index on `content` for text search

**Notes**:
- Conversation is identified by the sorted pair of nicknames
- Query pattern: `WHERE (sender = A AND recipient = B) OR (sender = B AND recipient = A) ORDER BY inserted_at DESC`
- Alternatively: `WHERE least(sender, recipient) = least(A, B) AND greatest(sender, recipient) = greatest(A, B)` (uses the composite index)

### 3. registered_nicks

NickServ-managed registered nicknames.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | bigserial | PK | Auto-increment |
| nickname | varchar(16) | NOT NULL, UNIQUE | The registered nickname |
| password_hash | varchar(255) | NOT NULL | bcrypt hash |
| registered_at | timestamptz | NOT NULL, default now() | When registered |
| last_seen_at | timestamptz | | Last time identified user was online |
| inserted_at | timestamptz | NOT NULL, default now() | Ecto timestamp |
| updated_at | timestamptz | NOT NULL, default now() | Ecto timestamp |

**Indexes**:
- `idx_registered_nicks_nickname` — UNIQUE on `nickname` (lookup by nick)

### 4. registered_channels

ChanServ-managed registered channels.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | bigserial | PK | Auto-increment |
| name | varchar(50) | NOT NULL, UNIQUE | Channel name (with #) |
| founder_nickname | varchar(16) | NOT NULL | Nickname of the founder |
| topic | text | | Persisted topic |
| modes | varchar(50) | default "" | Persisted mode string (e.g., "+mt") |
| mode_key | varchar(100) | | Persisted channel password (if +k) |
| mode_limit | integer | | Persisted user limit (if +l) |
| registered_at | timestamptz | NOT NULL, default now() | When registered via ChanServ |
| inserted_at | timestamptz | NOT NULL, default now() | Ecto timestamp |
| updated_at | timestamptz | NOT NULL, default now() | Ecto timestamp |

**Indexes**:
- `idx_registered_channels_name` — UNIQUE on `name`

### 5. access_list_entries

ChanServ access list for registered channels.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | bigserial | PK | Auto-increment |
| channel_name | varchar(50) | NOT NULL | References registered channel |
| nickname | varchar(16) | NOT NULL | The privileged user |
| level | varchar(10) | NOT NULL | Enum: founder, sop, aop, vop |
| added_by | varchar(16) | NOT NULL | Who added this entry |
| inserted_at | timestamptz | NOT NULL, default now() | Ecto timestamp |

**Indexes**:
- `idx_access_list_channel_nickname` — UNIQUE composite on `(channel_name, nickname)`
- `idx_access_list_channel_level` — Composite on `(channel_name, level)` for listing by level

**Constraints**:
- Only one entry per (channel_name, nickname) — a user has exactly one access level per channel
- `level` must be one of: founder, sop, aop, vop

### 6. bans

Persisted bans for registered channels only.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | bigserial | PK | Auto-increment |
| channel_name | varchar(50) | NOT NULL | Channel where the ban applies |
| banned_nickname | varchar(16) | NOT NULL | The banned user |
| banned_by | varchar(16) | NOT NULL | Who set the ban |
| reason | varchar(255) | | Optional reason |
| inserted_at | timestamptz | NOT NULL, default now() | When banned |

**Indexes**:
- `idx_bans_channel_nickname` — UNIQUE composite on `(channel_name, banned_nickname)`
- `idx_bans_channel` — On `(channel_name)` for loading all bans

**Notes**:
- Bans for unregistered channels exist only in-memory (GenServer state)
- Bans for registered channels are persisted here AND loaded into GenServer on channel startup

---

## In-Memory Entities

### User Session (LiveView assigns + Presence)

```elixir
# Stored in LiveView socket assigns
%{
  nickname: "Rodrigo",
  alt_nickname: "Rodrigo_",
  connected_at: ~U[2026-02-09 12:00:00Z],
  away: false,
  away_message: nil,
  identified: false,
  registered_nick_id: nil,
  active_channel: "#lobby",
  channels: ["#lobby", "#elixir"],
  pm_conversations: ["Admin"],
  command_history: [],          # Last 50 commands
  unread: %{"#elixir" => true}  # Unread indicators
}
```

### Channel State (GenServer)

```elixir
# Held in RetroHexChat.Channels.Server state
%{
  name: "#elixir",
  topic: "Welcome to #elixir!",
  modes: %{
    moderated: false,    # +m
    invite_only: false,  # +i
    topic_locked: true,  # +t
    key: nil,            # +k <password>
    limit: nil           # +l <N>
  },
  members: %{
    "Rodrigo" => %{role: :operator, joined_at: ~U[2026-02-09 12:00:00Z]},
    "Helper"  => %{role: :voiced,   joined_at: ~U[2026-02-09 12:01:00Z]},
    "Newbie"  => %{role: :regular,  joined_at: ~U[2026-02-09 12:02:00Z]}
  },
  bans: MapSet.new(["BadUser"]),
  registered: true,
  founder: "Rodrigo",
  created_at: ~U[2026-02-09 12:00:00Z]
}
```

### Rate Limit State (ETS)

```elixir
# ETS table: :retro_hex_chat_rate_limits
# Key: {nickname, :message | :command}
# Value: {count, window_start_timestamp}
{{"Rodrigo", :message}, {3, 1707480000}}
{{"Rodrigo", :command}, {1, 1707480000}}

# Mute entries (set when rate limit is exceeded)
# Key: {nickname, :muted}
# Value: {true, muted_until_timestamp}
# Absent key or expired timestamp = not muted
{{"Rodrigo", :muted}, {true, 1707480005}}
```

**Mute State Design**: When a user exceeds the rate limit (5 msg/sec
or 2 cmd/sec), the `RateLimit.Limiter` inserts a mute entry in ETS
with a `muted_until` timestamp (current time + 2–3 seconds). The
LiveView checks `RateLimit.Limiter.muted?(nickname)` before processing
input. While muted, the input field is visually disabled and a system
message is shown: "You are sending messages too fast. Please wait."
The mute auto-clears when the timestamp expires — no cleanup process
needed, the next `muted?/1` call simply checks `now > muted_until`.

---

## Entity Relationships

```text
registered_nicks
  └── 1:N → access_list_entries (via nickname)

registered_channels
  ├── 1:N → access_list_entries (via channel_name)
  └── 1:N → bans (via channel_name)

messages
  └── belongs to a channel (via channel_name)

private_messages
  └── between two users (via sender_nickname, recipient_nickname)
```

### Context Ownership

PostgreSQL schemas are owned by the bounded context that manages their
lifecycle:

| Schema | Context | Rationale |
|--------|---------|-----------|
| `registered_nick.ex` | **Services** | Managed by NickServ GenServer (register, identify, drop) |
| `registered_channel.ex` | **Services** | Managed by ChanServ GenServer (register, drop) |
| `access_list_entry.ex` | **Services** | Managed by ChanServ access list operations |
| `ban.ex` | **Services** | Managed by ChanServ for persisted bans |
| `message.ex` | **Chat** | Managed by Chat.Service (send, persist, query) |
| `private_message.ex` | **Chat** | Managed by Chat.Service (send, persist, query) |

The **Accounts** context owns only in-memory concerns: `session.ex`
(LiveView assigns struct), `nickname_validator.ex` (validation rules
like length, allowed characters, reserved names), and `policy.ex`
(identity checks such as "is this user identified?"). Accounts never
touches PostgreSQL directly — it delegates persistence to Services
(for nick registration) and Chat (for messages).

---

## State Transitions

### Channel Lifecycle

```text
                  /join (first user)
  [Not Exists] ─────────────────────→ [Active: GenServer running]
                                           │
                              Last user leaves?
                              ├─ Unregistered → [Terminated: process killed]
                              └─ Registered   → [Persisted: stays in DB,
                                                  GenServer may stay or
                                                  restart on next join]
```

### Nickname Lifecycle

```text
  [Available] ──connect──→ [In Use (unregistered)]
       ↑                        │
       │                  /ns register
       │                        ↓
       │              [In Use (registered, identified)]
       │                        │
       │                  disconnect
       │                        ↓
       └──────────────── [Available (registered in DB)]
                                │
                          connect by other
                                ↓
                    [In Use (registered, NOT identified)]
                          │                    │
                    /ns identify            60s timeout
                    (correct pass)              │
                          │                    ↓
                          ↓           [Force rename to Guest_XXXXX]
                  [In Use (identified)]
```

**Guest_XXXXX Collision Handling**: When NickServ generates a guest
nickname after identify timeout, the following retry logic applies:

1. Generate `Guest_` + 5 random digits (e.g., `Guest_83721`)
2. Check uniqueness against all currently connected users (via Presence)
3. If taken, retry with new random digits (up to 10 attempts)
4. If all 10 attempts collide, fall back to 10-digit suffix (`Guest_XXXXXXXXXX`)
5. The generated nickname is guaranteed unique before the force-rename
   broadcast is sent

### Channel Mode Effects

```text
  +m (moderated): regular users → input disabled
  +i (invite-only): non-invited → /join denied
  +t (topic lock): non-operators → /topic denied
  +k (keyed): no password → /join denied
  +l (limited): channel full → /join denied
  +o (op): user → operator role in membership
  +v (voice): user → voiced role in membership
```

---

## Migration Order

1. `create_messages` — messages table with indexes
2. `create_private_messages` — private messages table with indexes
3. `create_registered_nicks` — NickServ registrations
4. `create_registered_channels` — ChanServ registrations
5. `create_access_list_entries` — ChanServ access lists
6. `create_bans` — Persisted bans for registered channels
7. `enable_pg_trgm` — Enable pg_trgm extension for trigram search
