# Data Model: Flood Protection (013)

**Feature**: 013-flood-protection
**Date**: 2026-02-12

## Entities

### 1. FloodProtectionSetting (PostgreSQL — persistent, cold data)

Single-row-per-user table storing user-configurable flood protection thresholds. Only for registered users.

**Table**: `flood_protection_settings`
**Primary Key**: `owner_nickname` (string, references `registered_nicks`)

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| `owner_nickname` | string(16) | — | PK, FK → registered_nicks, NOT NULL | The registered user who owns these settings |
| `flood_threshold` | integer | 10 | NOT NULL, > 0, <= 100 | Messages from a single sender within the flood window that trigger auto-ignore |
| `flood_window_seconds` | integer | 15 | NOT NULL, > 0, <= 300 | Time window (in seconds) for flood detection |
| `auto_ignore_duration_seconds` | integer | 300 | NOT NULL, > 0, <= 86400 | How long (in seconds) an auto-ignored user stays ignored. 300 = 5 minutes |
| `spam_threshold` | integer | 3 | NOT NULL, > 0, <= 50 | Number of identical messages before duplicate detection blocks display |
| `spam_window_seconds` | integer | 10 | NOT NULL, > 0, <= 120 | Time window (in seconds) for duplicate message detection |
| `ctcp_reply_limit` | integer | 2 | NOT NULL, > 0, <= 20 | Maximum CTCP replies sent per CTCP reply window |
| `ctcp_reply_window_seconds` | integer | 10 | NOT NULL, > 0, <= 120 | Time window (in seconds) for CTCP reply limiting |
| `inserted_at` | utc_datetime_usec | now() | NOT NULL | Record creation timestamp |
| `updated_at` | utc_datetime_usec | now() | NOT NULL | Last update timestamp |

**Indexes**: None beyond the primary key (single-row lookups only).

**Cascade**: `ON DELETE CASCADE` from `registered_nicks` — if a user's registration is deleted, their flood protection settings are removed.

### 2. FloodProtection Settings (In-Memory — domain map)

In-memory representation used by the Session struct. Identical structure for both registered and guest users.

```
%{
  flood_threshold: pos_integer(),         # default: 10
  flood_window_seconds: pos_integer(),    # default: 15
  auto_ignore_duration_seconds: pos_integer(), # default: 300 (5 min)
  spam_threshold: pos_integer(),          # default: 3
  spam_window_seconds: pos_integer(),     # default: 10
  ctcp_reply_limit: pos_integer(),        # default: 2
  ctcp_reply_window_seconds: pos_integer() # default: 10
}
```

### 3. FloodTracker (In-Memory — socket assigns, hot data)

Per-user in-memory state tracking incoming message counts per sender. Lives in socket assigns as `flood_tracker`.

```
%{
  senders: %{
    downcased_nickname => %{
      timestamps: [integer()],    # monotonic timestamps of received messages
      added_at: integer()         # monotonic time when this sender was first tracked (for LRU eviction)
    }
  },
  max_senders: pos_integer()      # cap: 50
}
```

**Lifecycle**: Created on LiveView mount. Updated on each incoming message. Sender entries evicted when `max_senders` cap reached (oldest `added_at` removed first). Entire tracker destroyed on disconnect.

### 4. DuplicateTracker (In-Memory — socket assigns, hot data)

Per-user in-memory state tracking recent message content per sender-target pair. Lives in socket assigns as `duplicate_tracker`.

```
%{
  entries: %{
    {downcased_sender, target_key} => [
      %{content: String.t(), timestamp: integer()}  # monotonic timestamps
    ]
  },
  max_senders: pos_integer()    # cap: 50 (shared with flood tracker concept)
}
```

Where `target_key` is:
- `{:channel, "channel_name"}` for channel messages
- `{:pm, "sender_nick"}` for private messages

**Lifecycle**: Same as FloodTracker — created on mount, updated per message, destroyed on disconnect.

### 5. Auto-Ignore Tracking (In-Memory — socket assigns, hot data)

Per-user state tracking which senders were auto-ignored and cooldown status. Lives in socket assigns as `auto_ignore_state`.

```
%{
  active: %{
    downcased_nickname => %{
      timer_ref: reference(),     # Process.send_after timer reference
      expires_at: DateTime.t()    # when the auto-ignore expires
    }
  },
  cooldowns: %{
    downcased_nickname => integer()  # monotonic time when cooldown expires
  }
}
```

**Lifecycle**: Entries added when auto-ignore triggers. Entries removed when timer fires or user manually removes ignore. Cooldown added when user manually removes an auto-ignored sender. Entire state destroyed on disconnect.

### 6. CTCP Reply Tracker (In-Memory — socket assigns, hot data)

Per-user state tracking outgoing CTCP reply timestamps. Lives in socket assigns as `ctcp_reply_tracker`.

```
%{
  timestamps: [integer()]   # monotonic timestamps of sent CTCP replies
}
```

**Lifecycle**: Created on mount. Updated when a CTCP reply is sent. Old timestamps pruned on each check. Destroyed on disconnect.

## Relationships

```
registered_nicks (existing)
  └─── flood_protection_settings (1:1, ON DELETE CASCADE)

Session struct (in-memory)
  ├─── flood_protection: map()        # settings (loaded from DB for registered, defaults for guests)
  └─── (socket assigns)
       ├─── flood_tracker: map()      # per-sender message count tracking
       ├─── duplicate_tracker: map()  # per-sender-target duplicate detection
       ├─── auto_ignore_state: map()  # auto-ignore timers and cooldowns
       └─── ctcp_reply_tracker: map() # outgoing CTCP reply limiting

ignore_list (existing, in Session)
  └─── auto-ignore entries are regular IgnoreEntry structs with expires_at set
       (tracked separately in auto_ignore_state to support cooldown logic)
```

## State Transitions

### Auto-Ignore Lifecycle

```
[No Tracking] ──(message received)──> [Tracking: count < threshold]
                                          │
                                    (message received, count >= threshold)
                                          │
                                          ▼
                                    [Auto-Ignored]
                                      │         │
                            (timer expires)   (manual un-ignore)
                                      │         │
                                      ▼         ▼
                              [No Tracking]  [Cooldown Active]
                                                │
                                          (60s elapsed)
                                                │
                                                ▼
                                          [No Tracking]
```

### Duplicate Detection

```
[No History] ──(message from sender to target)──> [1 message recorded]
                                                       │
                                                 (same message again)
                                                       │
                                                       ▼
                                                 [2 messages recorded]
                                                       │
                                                 (same message again)
                                                       │
                                                       ▼
                                                 [Threshold reached — block display]
                                                       │
                                                 (window expires / different message)
                                                       │
                                                       ▼
                                                 [Reset / updated history]
```
