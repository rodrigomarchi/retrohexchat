# Data Model: Contextual Tips & Progressive Disclosure

**Feature**: 029-contextual-tips | **Date**: 2026-02-14

## Overview

This feature uses **client-side storage only** (localStorage). No database migrations, schemas, or server-side persistence needed. All state is managed in the browser.

## Entities

### TipDefinition (compile-time constant)

Defines the 5 available tips. Stored as a JS constant array — not persisted.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Unique identifier (e.g., `"first_message"`, `"first_join"`, `"first_pm"`, `"first_highlight"`, `"idle_help"`) |
| `text` | `string` | Display text in Portuguese |
| `preemptedBy` | `string \| null` | Tip ID or action that preempts this tip (e.g., `"help_used"` preempts `"idle_help"`) |

### TipSeenState (localStorage)

Tracks which tips have been shown to the user.

**Key**: `retro_hex_chat_tips_seen`
**Value**: JSON object

```json
{
  "first_message": true,
  "first_join": true,
  "first_pm": false,
  "first_highlight": false,
  "idle_help": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `[tipId]` | `boolean` | `true` if tip has been seen/dismissed; absent or `false` if not yet seen |

### GlobalSuppression (localStorage)

Controls whether all tips are globally disabled.

**Primary key**: `retro_hex_chat_tips_suppressed`
**Backup key**: `retro_hex_chat_tips_suppressed_backup`
**Value**: `"true"` when suppressed; absent when active

### TipQueue (runtime, in-memory JS)

Manages pending tips waiting to display. Not persisted — resets on page reload.

| Field | Type | Description |
|-------|------|-------------|
| `queue` | `Array<TipDefinition>` | Ordered list of pending tips |
| `isShowing` | `boolean` | Whether a toast is currently visible |
| `cooldownTimer` | `number \| null` | setTimeout ID for 2-second gap between tips |

## State Transitions

```
Tip Trigger Received
  │
  ├── Is globally suppressed? → DISCARD
  ├── Is tip already seen? → DISCARD
  ├── Is onboarding wizard active? → DISCARD
  ├── Is preempted by prior action? → Mark as SEEN, DISCARD
  │
  └── Add to queue
        │
        ├── Toast currently showing? → WAIT in queue
        ├── Dialog/modal open? → WAIT in queue
        │
        └── Show toast
              │
              ├── User clicks "Entendi!" → Mark SEEN, dismiss, process queue after 2s
              ├── User checks "Não mostrar mais" → Set SUPPRESSED, dismiss, clear queue
              └── 8 seconds elapsed → Mark SEEN, auto-dismiss, process queue after 2s
```

## localStorage Key Summary

| Key | Purpose | Value Format | Resilience |
|-----|---------|-------------|------------|
| `retro_hex_chat_tips_seen` | Per-tip seen tracking | JSON object | Normal — can be lost without critical impact |
| `retro_hex_chat_tips_suppressed` | Global suppression flag | `"true"` or absent | High — backed up to secondary key |
| `retro_hex_chat_tips_suppressed_backup` | Backup of suppression | `"true"` or absent | Redundant copy |

## Relationship to Existing Data

- **No database changes** — this feature is entirely client-side
- **No migrations** — no PostgreSQL tables or columns affected
- **Settings integration**: The Options dialog Display panel reads/writes the `retro_hex_chat_tips_suppressed` localStorage key via `push_event` to the JS hook. The actual toggle state in `user_preferences.display` is a UI convenience that syncs to localStorage — localStorage is the source of truth.
