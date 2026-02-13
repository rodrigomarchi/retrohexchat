# Data Model: Special Messages

**Feature Branch**: `020-special-messages`
**Date**: 2026-02-13

## Entity Changes

### 1. Server Settings (New — `Services.ServerSetting`)

**New table: `server_settings`**

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigint | PK, auto-increment | Row identifier |
| key | varchar(50) | NOT NULL, UNIQUE | Setting key (e.g., "motd") |
| value | text | NULL allowed | Setting value (MOTD text, etc.) |
| updated_by | varchar(16) | NULL allowed | Nickname of last admin who updated |
| inserted_at | utc_datetime_usec | NOT NULL | Creation timestamp |
| updated_at | utc_datetime_usec | NOT NULL | Last update timestamp |

**Indexes**:
- `idx_server_settings_key` — UNIQUE on `key`

**Validation rules**:
- `key` must be a non-empty string, max 50 characters
- `value` may be null (represents cleared/unset setting)
- `updated_by` max 16 characters (matching nickname length constraint)

### 2. Channel Welcome Message (New — `Services.ChannelWelcomeMessage`)

**New table: `channel_welcome_messages`**

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigint | PK, auto-increment | Row identifier |
| channel_name | varchar(50) | NOT NULL, UNIQUE | Channel this welcome belongs to |
| message | text | NOT NULL | Welcome message text |
| set_by | varchar(16) | NOT NULL | Nickname of user who set the message |
| inserted_at | utc_datetime_usec | NOT NULL | Creation timestamp |
| updated_at | utc_datetime_usec | NOT NULL | Last update timestamp |

**Indexes**:
- `idx_channel_welcome_messages_channel_name` — UNIQUE on `channel_name`

**Validation rules**:
- `channel_name` must start with `#`, max 50 characters
- `message` must be a non-empty string (empty message = clear welcome)
- `set_by` max 16 characters
- One welcome message per channel (upsert on channel_name)

### 3. Session Struct (Modified — `Accounts.Session`)

**New fields**:
```
user_modes: MapSet.t(atom())           # Default: MapSet.new()
welcomed_channels: MapSet.t(String.t()) # Default: MapSet.new()
```

**`user_modes`**: Tracks active user modes for this session. Initially only `:wallops` (`+w`), but designed for future expansion (+i invisible, etc.). Resets on disconnect.

**`welcomed_channels`**: Tracks channels where the user has already seen the welcome message during this session. Prevents showing the welcome on part+rejoin. Resets on disconnect.

### 4. Handler Context (Modified — `Commands.Handler`)

**New fields**:
```
context :: %{
  ...existing fields...,
  is_admin: boolean(),            # True if identified + in admin config list
  is_server_operator: boolean()   # True if identified + in server_operator config list
}
```

### 5. Channel Server State (Modified — `Channels.Server`)

**New field in state**:
```
welcome_message: %{message: String.t(), set_by: String.t()} | nil
```

Loaded from `channel_welcome_messages` table on channel GenServer init. Updated via `/setwelcome` and `/clearwelcome` commands (both DB and in-memory state).

## Database Migrations

### Migration 1: Create `server_settings` table

```sql
CREATE TABLE server_settings (
  id BIGSERIAL PRIMARY KEY,
  key VARCHAR(50) NOT NULL,
  value TEXT,
  updated_by VARCHAR(16),
  inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
  updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL
);

CREATE UNIQUE INDEX idx_server_settings_key ON server_settings (key);
```

### Migration 2: Create `channel_welcome_messages` table

```sql
CREATE TABLE channel_welcome_messages (
  id BIGSERIAL PRIMARY KEY,
  channel_name VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  set_by VARCHAR(16) NOT NULL,
  inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
  updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL
);

CREATE UNIQUE INDEX idx_channel_welcome_messages_channel_name
  ON channel_welcome_messages (channel_name);
```

## Application Configuration

### New config keys

```
config :retro_hex_chat,
  admins: ["AdminNick"],              # List of admin nicknames
  server_operators: ["OperNick"]      # List of server operator nicknames
```

Admin and operator lists are read from application config. Users must be identified via NickServ to activate their privileges.

## PubSub Events (New)

### Global Announcement
```
Topic: "server:announcements"
Event: {:announcement, %{
  sender: String.t(),
  content: String.t(),
  timestamp: DateTime.t()
}}
```
Delivered to all subscribers. Bypasses ignore lists. Displayed in the active window.

### Wallops
```
Topic: "server:wallops"
Event: {:wallops, %{
  sender: String.t(),
  content: String.t(),
  timestamp: DateTime.t()
}}
```
Delivered to all subscribers. PubSub handler filters: only displays if recipient has `:wallops` user mode active.

### MOTD Updated (Cache Invalidation)
```
Topic: "server:settings"
Event: {:motd_updated, %{content: String.t() | nil}}
```
Broadcast when admin sets/clears MOTD. All LiveView processes update their cached MOTD value.

### Welcome Message Changed
```
Topic: "channel:#{channel_name}"
Event: {:welcome_changed, %{
  channel: String.t(),
  message: String.t() | nil,
  set_by: String.t() | nil
}}
```
Broadcast to channel subscribers when welcome message is set or cleared. Updates the cached welcome message in each subscriber's state (not critical — mainly for operators to confirm the change).

## In-Memory State Summary

| State | Location | Lifetime | Purpose |
|-------|----------|----------|---------|
| User modes (+w) | Session struct | Per-session | Wallops opt-in |
| Welcomed channels set | Session struct | Per-session | Prevent duplicate welcome messages |
| MOTD cache | Application env / Agent | Application lifetime | Fast MOTD read on connect |
| Channel welcome message | Channel.Server state | Channel process lifetime | Fast welcome read on join |
| Admin/oper config | Application config | Application lifetime | Role checks |

## State Transitions

### MOTD Lifecycle
```
(no MOTD) --[/setmotd]--> MOTD set --[/setmotd]--> MOTD updated
                              |
                        [/clearmotd]
                              |
                              v
                         (no MOTD)
```

### Channel Welcome Message Lifecycle
```
(no welcome) --[/setwelcome]--> Welcome set --[/setwelcome]--> Welcome updated
                                    |
                              [/clearwelcome]
                                    |
                                    v
                              (no welcome)
```

### User Mode (+w) Lifecycle
```
(+w off) --[/umode +w]--> (+w on) --[/umode -w]--> (+w off)
                              |
                        [disconnect]
                              |
                              v
                          (+w off)
```
