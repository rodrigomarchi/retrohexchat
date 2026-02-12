# Data Model: Scripting & Aliases (Simplified)

**Feature**: 018-scripting-aliases
**Date**: 2026-02-12

## Entities

### 1. Alias (Persisted)

Represents a user-defined command shortcut with variable expansion.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, auto-increment | Database identifier |
| owner_nickname | string(16) | FK → registered_nicks, NOT NULL | Owner's registered nickname |
| name | string(30) | NOT NULL | Alias name without `/` prefix (e.g., "hi") |
| expansion | string(500) | NOT NULL | Expansion string with optional variables |
| position | integer | NOT NULL, default: 0 | Display ordering in editor |
| inserted_at | utc_datetime_usec | auto | Creation timestamp |
| updated_at | utc_datetime_usec | auto | Last update timestamp |

**Indexes**:
- `idx_aliases_owner` on `owner_nickname`
- `aliases_owner_name_unique` unique on `lower(owner_nickname), lower(name)`

**Validation rules**:
- `name`: 1–30 chars, only `[a-zA-Z0-9_-]`, case-insensitive uniqueness per owner
- `expansion`: 1–500 chars, must not contain `|`, `&&`, `;`, or newline characters

**In-memory representation** (Session field `aliases`):
```
%{
  entries: [
    %AliasEntry{name: "hi", expansion: "/me says hello!", position: 0},
    %AliasEntry{name: "greet", expansion: "/me waves at $1", position: 1}
  ]
}
```

---

### 2. Custom Menu Item (Persisted)

Represents a user-defined context menu entry for nicklist or channel tabs.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, auto-increment | Database identifier |
| owner_nickname | string(16) | FK → registered_nicks, NOT NULL | Owner's registered nickname |
| menu_type | string(10) | NOT NULL, enum: "nicklist"/"channel" | Which context menu this belongs to |
| label | string(50) | NOT NULL | Display text in the menu |
| command | string(500) | NOT NULL | Command string with variable expansion |
| position | integer | NOT NULL, default: 0 | Display ordering in menu |
| inserted_at | utc_datetime_usec | auto | Creation timestamp |
| updated_at | utc_datetime_usec | auto | Last update timestamp |

**Indexes**:
- `idx_custom_menu_items_owner` on `owner_nickname`
- `custom_menu_items_owner_type_label_unique` unique on `lower(owner_nickname), menu_type, lower(label)`

**Validation rules**:
- `label`: 1–50 chars, no empty strings
- `command`: 1–500 chars
- `menu_type`: must be "nicklist" or "channel"
- Max 10 entries per menu_type per owner (enforced in domain logic)

**In-memory representation** (Session field `custom_menus`):
```
%{
  entries: [
    %CustomMenuItem{menu_type: :nicklist, label: "Send greeting", command: "/notice $1 Welcome!", position: 0},
    %CustomMenuItem{menu_type: :channel, label: "Announce topic", command: "/me announces $chan", position: 0}
  ]
}
```

---

### 3. Auto-Respond Rule (Persisted)

Represents an event-triggered automatic command execution rule.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, auto-increment | Database identifier |
| owner_nickname | string(16) | FK → registered_nicks, NOT NULL | Owner's registered nickname |
| trigger_event | string(15) | NOT NULL, enum: "on_join"/"on_part"/"on_nick_change" | Which event triggers this rule |
| channel_filter | string(50) | nullable | Channel to match (nil = all channels) |
| command | string(500) | NOT NULL | Command string with variable expansion |
| enabled | boolean | NOT NULL, default: true | Whether the rule is active |
| position | integer | NOT NULL, default: 0 | Display ordering in editor |
| inserted_at | utc_datetime_usec | auto | Creation timestamp |
| updated_at | utc_datetime_usec | auto | Last update timestamp |

**Indexes**:
- `idx_autorespond_rules_owner` on `owner_nickname`

**Validation rules**:
- `trigger_event`: must be one of "on_join", "on_part", "on_nick_change"
- `channel_filter`: if present, must start with `#`, max 50 chars
- `command`: 1–500 chars
- Max 10 rules per owner (enforced in domain logic)

**In-memory representation** (Session field `autorespond_rules`):
```
%{
  entries: [
    %AutoRespondRule{
      id: 1,
      trigger_event: :on_join,
      channel_filter: "#welcome",
      command: "/notice $nick Welcome!",
      enabled: true,
      position: 0
    }
  ]
}
```

---

### 4. Timer (Session-only, NOT persisted)

Represents a scheduled command execution. Lives entirely in socket assigns.

| Field | Type | Description |
|-------|------|-------------|
| name | string | Unique per user, timer identifier |
| type | atom | `:once` or `:repeat` |
| interval | integer | Delay/interval in seconds |
| command | string | Command to execute on fire |
| timer_ref | reference | `Process.send_after` reference for cancellation |
| created_at | DateTime | When the timer was created |

**Socket assign representation** (`socket.assigns.user_timers`):
```
%{
  "remind" => %{type: :once, interval: 1800, command: "/me reminder!", timer_ref: #Ref<...>, created_at: ~U[...]},
  "heartbeat" => %{type: :repeat, interval: 600, command: "/me is here", timer_ref: #Ref<...>, created_at: ~U[...]}
}
```

**Constraints** (enforced in domain logic):
- Max 5 active timers per user
- Min interval: 10 seconds for repeat, 1 second for one-shot
- Max interval: 86400 seconds (24 hours)
- Timer name: 1–30 chars, `[a-zA-Z0-9_-]`

---

## Relationships

```
registered_nicks (existing)
  ├── 1:N → aliases
  ├── 1:N → custom_menu_items
  └── 1:N → autorespond_rules

(No DB relationship for timers — session-only)
```

## State Transitions

### Alias Lifecycle
```
Created (via editor or /alias add)
  → Active (expands when invoked)
  → Edited (expansion updated)
  → Deleted (removed from list)
```

### Timer Lifecycle
```
Created (/timer name [repeat] seconds command)
  → Scheduled (Process.send_after active)
  → Fired (command executed)
    → [once] Removed from timer map
    → [repeat] Re-scheduled (new Process.send_after)
  → Stopped (/timer stop name → Process.cancel_timer)
  → Lost (page reload/disconnect → process dies, all timers gone)
```

### Auto-Respond Rule Lifecycle
```
Created (via editor or /autorespond add)
  → Active (evaluates on matching events)
  → Rate-limited (cooldown active for specific triggering user)
  → Disabled (enabled: false, skipped during evaluation)
  → Deleted (removed from list)
```
