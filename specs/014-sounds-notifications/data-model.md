# Data Model: 014 Sounds & Notifications

**Date**: 2026-02-12
**Feature Branch**: `014-sounds-notifications`

## Entities

### 1. SoundSetting (persisted — PostgreSQL)

Stores per-user sound preferences for registered users. One row per user.

| Field | Type | Constraints | Default | Description |
|-------|------|-------------|---------|-------------|
| owner_nickname | string(16) | PK, FK → registered_nicks | — | Owner's registered nickname |
| sound_mappings | jsonb | NOT NULL | `{}` | Map of event_type → sound_name (e.g., `{"message": "ding_low", "pm": "chime_high", "highlight": "alert", ...}`) |
| flash_settings | jsonb | NOT NULL | `{}` | Map of event_type → boolean (e.g., `{"pm": true, "highlight": true, "message": false, ...}`) |
| inserted_at | utc_datetime_usec | NOT NULL | — | Creation timestamp |
| updated_at | utc_datetime_usec | NOT NULL | — | Last update timestamp |

**Notes**:
- JSONB columns allow easy evolution when new event types are added
- The 10 event types: `message`, `pm`, `highlight`, `join`, `part`, `kick`, `connect`, `disconnect`, `buddy_online`, `buddy_offline`
- Sound names reference the built-in catalog (e.g., `"ding_low"`, `"chime_high"`, `"none"`)
- Flash settings default: `pm: true`, `highlight: true`, `buddy_online: true`, all others `false`

### 2. Sound Settings In-Memory Map (Session struct)

Used for both registered and guest users at runtime.

```elixir
%{
  sound_mappings: %{
    message: "ding_low",
    pm: "chime_high",
    highlight: "alert",
    join: "click",
    part: "click",
    kick: "buzz",
    connect: "chime_short",
    disconnect: "chime_low",
    buddy_online: "notify",
    buddy_offline: "blip"
  },
  flash_settings: %{
    message: false,
    pm: true,
    highlight: true,
    join: false,
    part: false,
    kick: false,
    connect: false,
    disconnect: false,
    buddy_online: true,
    buddy_offline: false
  }
}
```

### 3. Mute State (client-side — localStorage)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `retro_hex_chat_mute` | string ("true"/"false") | "false" | Global mute toggle (already exists) |

**Notes**:
- Already implemented in `sound_hook.js`
- No server-side persistence needed — purely a client-side audio concern
- Persists across page reloads automatically via localStorage

### 4. Typing State (transient — in-memory only)

| Field | Scope | Lifetime | Description |
|-------|-------|----------|-------------|
| `pm_typing_from` | socket assign | Until timeout or message sent | Nickname of the user currently typing in the active PM, or nil |
| `pm_typing_timer` | socket assign | Until timeout fires | Reference to `Process.send_after` timer for clearing typing state |

**Notes**:
- Not persisted anywhere — purely transient socket state
- Set when a `"typing"` PubSub event is received for the active PM
- Cleared by: 5-second timeout, message received from the typing user, or user switching away from PM view
- No new database table needed

### 5. Sound Catalog (static — hardcoded constant)

The catalog of available sounds is a static map defined in the JS sound hook. Each sound has a unique name and Web Audio API parameters.

```javascript
{
  "none":        null,  // No sound
  "beep":        { frequency: 520, duration: 0.1, volume: 0.2, waveType: "sine" },
  "ding_low":    { frequency: 440, duration: 0.15, volume: 0.2, waveType: "sine" },
  "ding_high":   { frequency: 880, duration: 0.15, volume: 0.25, waveType: "sine" },
  "chime_short": { frequency: 660, duration: 0.12, volume: 0.2, waveType: "sine" },
  "chime_long":  { frequency: 660, duration: 0.3, volume: 0.2, waveType: "sine" },
  "chime_high":  { frequency: 880, duration: 0.25, volume: 0.25, waveType: "sine" },
  "chime_low":   { frequency: 330, duration: 0.25, volume: 0.2, waveType: "sine" },
  "alert":       { frequency: 880, duration: 0.3, volume: 0.35, waveType: "square" },
  "buzz":        { frequency: 220, duration: 0.2, volume: 0.2, waveType: "sawtooth" },
  "click":       { frequency: 1200, duration: 0.05, volume: 0.15, waveType: "square" },
  "ring":        { frequency: 740, duration: 0.4, volume: 0.25, waveType: "sine" },
  "notify":      { frequency: 600, duration: 0.15, volume: 0.2, waveType: "triangle" },
  "blip":        { frequency: 480, duration: 0.08, volume: 0.15, waveType: "sine" },
  "whoosh":      { frequency: 300, duration: 0.25, volume: 0.15, waveType: "triangle" }
}
```

**Notes**:
- 14 sounds + "none" = 15 options total
- Catalog is static — same for all users
- Sound names are used as keys in `sound_mappings`
- The catalog also provides display labels for the UI dropdown (derived from names: "Ding Low", "Chime High", etc.)

## Relationships

```
registered_nicks (1) ──→ (0..1) sound_settings
                              │
                              ├── sound_mappings (JSONB: event_type → sound_name)
                              └── flash_settings (JSONB: event_type → boolean)

Session struct (in-memory)
  └── sound_settings (map — same shape as DB, loaded on identify)

Sound Catalog (static JS constant)
  └── Defines valid sound_name values for sound_mappings

Mute State (localStorage)
  └── Independent of sound_settings — controls audio output globally
```

## State Transitions

### Typing Indicator Lifecycle

```
IDLE ──[user starts typing]──→ TYPING ──[5s timeout]──→ IDLE
  │                              │
  │                              ├──[message sent]──→ IDLE
  │                              │
  │                              └──[user disconnects]──→ IDLE (via timeout)
  │
  └──[typing event from ignored user]──→ IDLE (no transition)
```

### Sound Settings Dialog Lifecycle

```
CLOSED ──[open dialog]──→ OPEN (draft = current settings)
                            │
                            ├──[change dropdown]──→ OPEN (draft updated)
                            │
                            ├──[Preview]──→ OPEN (play selected sound)
                            │
                            ├──[Apply]──→ OPEN (draft committed to session + DB)
                            │
                            ├──[OK]──→ CLOSED (draft committed to session + DB)
                            │
                            └──[Cancel / X]──→ CLOSED (draft discarded)
```
