# Data Model: Miscellaneous Polish (022)

**Date**: 2026-02-13
**Branch**: `022-misc-polish`

## Entity Summary

This feature is primarily in-memory and UI-driven. Only one existing schema is extended (no new migrations). Most state lives in socket assigns or static modules.

## Entities

### E1: UserPreferences Extension (Existing Schema)

**Schema**: `RetroHexChat.Chat.Schemas.UserPreference`
**Table**: `user_preferences` (existing)
**Column**: `display_settings` (JSONB, existing)

**New keys added to `display_settings` map**:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `timestamp_format` | atom (stored as string) | `:hh_mm` | Chat timestamp format: `:hh_mm`, `:hh_mm_ss`, `:dd_mm_hh_mm`, `:none` |
| `quit_message` | string | `"Leaving"` | Default quit message when no explicit message provided |

**Validation**:
- `timestamp_format` must be one of 4 valid atoms
- `quit_message` max 200 characters, non-empty after trim

**No migration needed** — JSONB column already exists and accepts arbitrary keys.

---

### E2: AwayReplyTracker (In-Memory, Socket Assign)

**Location**: `socket.assigns.away_replied_to`
**Type**: `MapSet.t(String.t())`
**Default**: `MapSet.new()`

**Lifecycle**:
- Created: On socket mount (empty MapSet)
- Updated: When auto-reply sent to a PM sender (add nickname)
- Reset: When user clears away status (replace with empty MapSet)
- Destroyed: When socket disconnects

**No persistence** — per-session only.

---

### E3: EmojiData (Static Module)

**Module**: `RetroHexChat.Chat.EmojiData`
**Type**: Compile-time data, no runtime state

**Structure**:
```
%{
  category: String.t(),
  emojis: [%{char: String.t(), name: String.t(), keywords: [String.t()]}]
}
```

**Categories** (8):
- Smileys & Emotion
- People & Body
- Animals & Nature
- Food & Drink
- Travel & Places
- Activities
- Objects
- Symbols

**Volume**: ~300 curated emojis (most commonly used subset)

**Functions**:
- `all/0` → list of category maps
- `search/1` → filtered emojis matching name/keyword query
- `by_category/1` → emojis for a specific category

---

### E4: PasteState (In-Memory, Socket Assign)

**Location**: `socket.assigns.paste_lines`
**Type**: `[String.t()] | nil`
**Default**: `nil`

**Lifecycle**:
- `nil`: No paste dialog shown
- `[lines]`: Paste dialog visible with these lines pending
- Reset to `nil` on send or cancel

---

### E5: QuitReason (In-Memory, Socket Assign)

**Location**: `socket.assigns.quit_reason`
**Type**: `String.t() | nil`
**Default**: `nil`

**Lifecycle**:
- Set by `/quit message` command dispatch
- Read during `cleanup_channels` for broadcast
- Falls back to `session.user_preferences.display.quit_message` or `"Leaving"`

---

## Relationships

```
UserPreferences (existing)
  └── display_settings (JSONB)
        ├── timestamp_format (new key)
        └── quit_message (new key)

Socket Assigns (runtime)
  ├── away_replied_to: MapSet<nickname>
  ├── paste_lines: [String] | nil
  ├── quit_reason: String | nil
  ├── show_emoji_picker: boolean
  ├── emoji_search: String
  └── emoji_category: String

EmojiData (static module)
  └── compile-time data, no runtime relationships
```

## State Transitions

### Away Auto-Reply State Machine

```
[Not Away] ──/away msg──▶ [Away, replied_to=∅]
                              │
                              ├── PM from User B (not in set)
                              │   → send auto-reply, add B to set
                              │   → [Away, replied_to={B}]
                              │
                              ├── PM from User B (in set)
                              │   → no auto-reply (skip)
                              │
                              ├── PM from User C (not in set)
                              │   → send auto-reply, add C to set
                              │   → [Away, replied_to={B, C}]
                              │
                              └── /away (clear)
                                  → [Not Away, replied_to=∅]
```

### Paste Dialog State Machine

```
[Idle] ──paste event (1 line)──▶ [Idle] (normal paste, no dialog)
[Idle] ──paste event (2+ lines)──▶ [Dialog Shown, lines=N]
                                       │
                                       ├── Cancel → [Idle]
                                       │
                                       └── Send All (if ≤100 lines)
                                           → dispatch lines with 300ms pacing
                                           → [Idle]
```
