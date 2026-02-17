# Data Model: P2P Security, Help & Polish

**Feature**: 039-p2p-security-help-polish
**Date**: 2026-02-16

## Entities

### No New Database Tables or Migrations

This feature does not require any new database tables or migrations. All changes use existing infrastructure:

### 1. P2P Rate Limit State (Ephemeral — ETS)

**Table**: `:p2p_rate_limits` (ETS, created in P2P application supervisor)

**Records**:

| Key Pattern | Fields | Purpose |
|-------------|--------|---------|
| `{:session_create, user_id}` | `{key, count, window_start_ms}` | Session creation counter (5/10min) |
| `{:signal, user_id}` | `{key, count, window_start_ms}` | Signaling message counter (100/min) |

**Lifecycle**: Created on first rate-check, auto-expires when window resets. Cleaned up periodically or on process restart.

### 2. User Preference — P2P Settings (Existing JSONB Column)

**Table**: `user_preferences` (existing)
**Column**: `message_settings` (existing JSONB)

**New nested key**:

```json
{
  "p2p_settings": {
    "turn_only": false
  }
}
```

**Default**: `turn_only: false` (privacy mode disabled)

**Read**: On `P2PSessionLive.mount/3`, extract from loaded user preferences.
**Write**: On `toggle_privacy_mode` event, merge into `message_settings`.

### 3. Help Topics (Compile-Time — Module Attributes)

**Module**: `RetroHexChat.Chat.HelpTopics.Features`

**New topics**:

| ID | Title | Category |
|----|-------|----------|
| `feature-p2p-sessions` | P2P Sessions | Features |
| `feature-file-transfer` | File Transfer | Features |
| `feature-audio-video-calls` | Audio/Video Calls | Features |
| `feature-privacy-settings` | Privacy Settings | Features |

**Updated topics**:

| ID | Module | Change |
|----|--------|--------|
| `keyboard-shortcuts` | `HelpTopics.KeyboardShortcuts` | Add P2P-related shortcuts (if any) |

### 4. Application Configuration (Existing — runtime.exs)

**New/modified config keys** (all under `:retro_hex_chat`):

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `turn_credentials_lifetime` | integer | `86_400` → change to `3_600` | Credential TTL (seconds) |
| `signaling_rate_limiter` | module | `Noop` → change to `P2P.SignalingRateLimit.ETS` | Rate limiter implementation |
| `p2p_session_rate_limit` | `{count, window_ms}` | `{5, 600_000}` | 5 sessions per 10 minutes |

## State Transitions

### P2P Session (Existing — No Changes)

```
pending → lobby → connecting → active → closed/expired/failed
```

### Privacy Mode Toggle

```
disabled (default) ←→ enabled (user toggles)
```

When enabled + TURN configured: `iceTransportPolicy: "relay"`
When enabled + TURN not configured: Warning message, fallback to `"all"`

## Relationships

```
User (registered_nick) ──1:N──▶ P2P Sessions (p2p_sessions)
User (registered_nick) ──1:1──▶ User Preferences (user_preferences)
User Preferences ──contains──▶ p2p_settings.turn_only (JSONB nested key)
P2P Session ──references──▶ Rate Limit State (ETS, by user_id)
Ignore List Entry ──blocks──▶ P2P Session Creation (via Policy.check_no_block/2)
```
