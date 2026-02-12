# Data Model: CTCP (Client-to-Client Protocol)

**Feature**: 012-ctcp-system
**Date**: 2026-02-12

## Entities

### 1. CTCP Settings (Persistent)

**Table**: `ctcp_settings`
**Schema**: `RetroHexChat.Chat.Schemas.CtcpSetting`

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| `owner_nickname` | `string(16)` | PK, FK → registered_nicks(nickname), NOT NULL | — | Owner of these settings |
| `enabled` | `boolean` | NOT NULL | `true` | Whether to respond to CTCP requests |
| `version_string` | `string(200)` | NOT NULL | `"RetroHexChat v1.0"` | Custom VERSION reply text |
| `finger_text` | `string(200)` | nullable | `nil` | Custom FINGER reply text (nil = auto-generate) |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | auto | Creation timestamp |
| `updated_at` | `utc_datetime_usec` | NOT NULL | auto | Last update timestamp |

**Relationships**:
- `owner_nickname` → `registered_nicks.nickname` (ON DELETE CASCADE)

**Validation Rules**:
- `owner_nickname`: required, max 16 characters
- `version_string`: required, max 200 characters
- `finger_text`: optional, max 200 characters when present

### 2. CTCP Settings (In-Memory)

**Module**: `RetroHexChat.Chat.CtcpSettings`
**Storage**: `Session.ctcp_settings` field

```elixir
%{
  enabled: true,                           # boolean
  version_string: "RetroHexChat v1.0",     # string, max 200
  finger_text: nil                         # string | nil, max 200
}
```

**Operations**:
- `new/0` → default settings map
- `get_enabled/1`, `get_version_string/1`, `get_finger_text/1`
- `set_enabled/2`, `set_version_string/2`, `set_finger_text/2`
- `save/2` → persist to DB (upsert)
- `load/1` → load from DB

### 3. CTCP Pending Request (Ephemeral)

**Storage**: Socket assigns (`socket.assigns.ctcp_pending`)

```elixir
%{
  request_id => %{
    target: String.t(),                        # target nickname
    type: :ping | :version | :time | :finger,  # CTCP type
    sent_at: integer(),                         # System.monotonic_time(:millisecond)
    timer_ref: reference()                      # Process.send_after reference
  }
}
```

**Lifecycle**:
1. Created when sender dispatches `/ctcp <target> <type>`
2. Timer fires after 10 seconds → timeout message, entry removed
3. Reply received → timer cancelled, entry removed, reply displayed
4. Self-CTCP → no entry created (immediate reply)

### 4. CTCP Rate Limit Tracker (Ephemeral)

**Storage**: Socket assigns (`socket.assigns.ctcp_rate_limits`)

```elixir
%{
  downcased_target => [monotonic_timestamp_1, monotonic_timestamp_2, ...]
}
```

**Rules**:
- Max 3 timestamps per target within 30-second window
- On send: prune timestamps older than 30s, check count < 3
- Downcased target for case-insensitive matching

### 5. Session Fields (Modified)

**Module**: `RetroHexChat.Accounts.Session`

New fields added:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ctcp_settings` | `map()` | `CtcpSettings.new()` | In-memory CTCP reply settings |
| `last_message_at` | `DateTime.t()` | `DateTime.utc_now()` | Last sent message timestamp (for FINGER idle) |

## PubSub Messages

### CTCP Request (sender → target)

```elixir
{:ctcp_request, %{
  type: :ping | :version | :time | :finger,
  sender: String.t(),
  request_id: String.t(),
  sent_at: integer()    # monotonic time, for PING round-trip
}}
```

Broadcast to: `"user:#{target}"`

### CTCP Reply (target → sender)

```elixir
{:ctcp_reply, %{
  type: :ping | :version | :time | :finger,
  sender: String.t(),       # the original request sender (reply recipient)
  replier: String.t(),      # the user sending the reply
  request_id: String.t(),
  value: String.t(),        # reply content (version string, time, finger text, or empty for ping)
  sent_at: integer()        # original sent_at from request (for PING latency)
}}
```

Broadcast to: `"user:#{original_sender}"`

## Migration

```elixir
create table(:ctcp_settings, primary_key: false) do
  add :owner_nickname,
      references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
      null: false,
      primary_key: true,
      size: 16

  add :enabled, :boolean, null: false, default: true
  add :version_string, :string, null: false, default: "RetroHexChat v1.0", size: 200
  add :finger_text, :string, null: true, size: 200

  timestamps(type: :utc_datetime_usec)
end
```
