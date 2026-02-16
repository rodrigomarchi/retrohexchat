# Data Model: Notification System

**Branch**: `032-notification-system` | **Date**: 2026-02-15

## Entities

### 1. Notification Preferences (extends existing UserPreferences)

Added as a `notifications` key in the `UserPreferences` map, persisted inside the existing `message_settings` JSONB column.

**Fields**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `sounds_enabled` | boolean | `true` | Global toggle for notification sounds |
| `browser_notifications` | boolean | `false` | Global toggle for browser native notifications |
| `title_flash_enabled` | boolean | `true` | Global toggle for title bar flashing |
| `privacy_mode` | boolean | `false` | Hide message content in toasts/browser notifications |
| `dnd_enabled` | boolean | `false` | Do Not Disturb mode |
| `trigger_mentions` | boolean | `true` | Notify when someone mentions my nick |
| `trigger_pms` | boolean | `true` | Notify when I receive a PM |
| `trigger_channel_messages` | boolean | `false` | Notify on any channel message |
| `trigger_joins_leaves` | boolean | `false` | Notify on joins/leaves |
| `channel_levels` | map | `%{}` | Per-channel notification levels. Keys: channel names, Values: `"normal"` \| `"mentions_only"` \| `"mute"` |

**Validation Rules**:
- `channel_levels` values must be one of: `"normal"`, `"mentions_only"`, `"mute"`
- PM level is always `"always"` and cannot be overridden (enforced in code, not stored)
- When a user leaves a channel, the corresponding `channel_levels` entry is removed

**Migration from existing `muted_channels`**:
- On load, if `muted_channels` list exists and `channel_levels` doesn't, convert each muted channel to `channel_levels[channel] = "mute"`
- Remove `muted_channels` from message_settings after migration

### 2. Notification Event (ephemeral, in-memory)

Passed from server to client via `push_event("notify", payload)`. Not persisted to database.

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (generated server-side) |
| `type` | string | `"mention"` \| `"pm"` \| `"channel_message"` \| `"join"` \| `"leave"` |
| `channel` | string \| nil | Source channel name (nil for PMs) |
| `sender` | string | Nickname of the message author |
| `content` | string | Message content preview (truncated to 100 chars) |
| `timestamp` | string | ISO 8601 timestamp |
| `highlighted` | boolean | Whether the message matched highlight/mention rules |

### 3. Notification Entry (client-side, session-scoped)

Stored in the notification center's in-memory list (socket assigns on server, mirrored to client).

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Same as the originating Notification Event id |
| `type` | string | `"mention"` \| `"pm"` \| `"channel_message"` |
| `channel` | string \| nil | Source channel or nil for PMs |
| `sender` | string | Who triggered the notification |
| `summary` | string | Human-readable summary (e.g., "Mario mentioned you in #dev") |
| `timestamp` | DateTime | When the notification was created |
| `read` | boolean | Whether the user has read/dismissed this notification |

**Constraints**:
- Maximum 50 entries (FIFO — oldest dropped when limit reached)
- Joins/leaves do not create notification center entries (only mentions, PMs, channel messages)
- Cleared by "Mark all as read" action

## State Locations

| State | Registered Users | Guests | Scope |
|-------|-----------------|--------|-------|
| Notification preferences | `message_settings` JSONB in `user_preferences` table | `localStorage: retro_hex_chat_notification_prefs` | Persistent |
| DND mode | Same as above | Same as above | Persistent |
| Notification entries | Socket assigns (`notification_entries`) | Socket assigns | Session (lost on disconnect) |
| Unread notification count | Socket assigns (`notification_count`) | Socket assigns | Session |
| Browser notification permission | Browser API (`Notification.permission`) | Browser API | Browser-level |
| Favicon badge state | Client JS variable | Client JS variable | Tab-level |
| Toast queue | Client JS variable (NotificationToastHook) | Same | Tab-level |

## Relationships

```text
UserPreferences (existing)
  └── notifications (new key in message_settings)
        ├── global toggles (sounds, browser, title_flash, privacy, dnd)
        ├── trigger rules (mentions, pms, channel_messages, joins_leaves)
        └── channel_levels (per-channel: normal/mentions_only/mute)

SoundSettings (existing, unchanged)
  └── sound_mappings (per-event-type sound selection)
  └── flash_settings (per-event-type flash toggle)

Note: SoundSettings remains separate. The notification system's
"sounds_enabled" global toggle gates ALL sounds. The per-event
sound selection in SoundSettings determines WHICH sound plays.
```

## Event Flow

```text
Server (PubSub message arrives)
  → ChatLive handle_info
    → Detect event type (message, PM, join, etc.)
    → Check highlight/mention (existing maybe_highlight)
    → Build notification event payload
    → Add to notification_entries (socket assign)
    → push_event("notify", payload) to client

Client (NotificationDispatcher receives "notify")
  → Check DND mode → if active, skip all except badge update
  → Check if target channel is active → if yes, skip toasts/sounds
  → Check per-channel level (normal/mentions_only/mute)
  → Check trigger rules (mentions, PMs, etc.)
  → For each enabled channel:
    → Toast: queue with max 3 visible, privacy mode check
    → Sound: check sounds_enabled + delegate to SoundHook
    → Title flash: check title_flash_enabled + delegate to TitleFlashHook
    → Browser notification: check browser_notifications + permission
    → Favicon badge: update/set red dot
    → Notification center badge: update count on bell icon
```
