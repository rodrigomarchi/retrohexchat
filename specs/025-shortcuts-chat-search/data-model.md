# Data Model: Keyboard Shortcuts & Chat Search

**Feature**: 025-shortcuts-chat-search
**Date**: 2026-02-13

## Entities

### 1. Shortcut Registry Entry (in-memory, domain module)

Extends existing `KeyBindings` module with category and metadata.

| Field | Type | Description |
|-------|------|-------------|
| action | atom | Unique action identifier (e.g., `:toggle_search`, `:window_next`) |
| category | atom | One of `:navigation`, `:chat`, `:formatting`, `:system` |
| label | string | Human-readable short name (e.g., "Search", "Next Window") |
| description | string | One-line description for cheatsheet (e.g., "Open/close search bar") |
| default_binding | binding_map | `%{key: string, modifiers: [atom]}` — immutable default |
| customizable | boolean | Whether users can rebind this action (formatting keys = false) |

**New actions to add** (12 total):

| Action | Category | Default Binding | Customizable | Label |
|--------|----------|-----------------|--------------|-------|
| `toggle_cheatsheet` | `:system` | Ctrl+Shift+/ | Yes | "Shortcut Cheatsheet" |
| `window_next` | `:navigation` | Ctrl+Shift+] | Yes | "Next Window" |
| `window_prev` | `:navigation` | Ctrl+Shift+[ | Yes | "Previous Window" |
| `window_1` | `:navigation` | Ctrl+Shift+1 | No | "Window 1" |
| `window_2` | `:navigation` | Ctrl+Shift+2 | No | "Window 2" |
| `window_3` | `:navigation` | Ctrl+Shift+3 | No | "Window 3" |
| `window_4` | `:navigation` | Ctrl+Shift+4 | No | "Window 4" |
| `window_5` | `:navigation` | Ctrl+Shift+5 | No | "Window 5" |
| `window_6` | `:navigation` | Ctrl+Shift+6 | No | "Window 6" |
| `window_7` | `:navigation` | Ctrl+Shift+7 | No | "Window 7" |
| `window_8` | `:navigation` | Ctrl+Shift+8 | No | "Window 8" |
| `window_9` | `:navigation` | Ctrl+Shift+9 | No | "Window 9" |

**Note**: `toggle_cheatsheet` replaces the current `open_help` binding on Ctrl+Shift+/. The `open_help` action needs a new default binding (e.g., Ctrl+Shift+F1 — but F1 is reserved). Decision: `open_help` retains Ctrl+Shift+/ as before; the cheatsheet is a sub-feature OF the help dialog, triggered by the same shortcut but showing the shortcuts tab. Alternatively, `toggle_cheatsheet` gets a NEW binding. See note below.

**Resolution**: The existing `open_help` already uses Ctrl+Shift+/. Rather than conflicting, the cheatsheet dialog IS a standalone dialog separate from the help system. Reassign: `open_help` keeps Ctrl+Shift+/, `toggle_cheatsheet` is triggered as a sub-action within the keyboard shortcuts help topic OR gets its own binding. **Final decision**: The cheatsheet replaces `open_help` on Ctrl+Shift+/ — it IS the quick-reference shortcut. The full Help dialog remains accessible via the Help menu and `/help` command. Update `open_help` default to no keyboard shortcut (menu-only).

### 2. Search State (LiveView socket assigns)

Extends existing search assigns with filter and highlight state.

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `search_visible` | boolean | `false` | Search bar shown/hidden |
| `search_query` | string | `""` | Current search text |
| `search_results` | list | `[]` | Matching message IDs (for history) |
| `search_result_count` | integer | `0` | Total match count |
| `search_current_index` | integer | `0` | Active match position (1-indexed, 0 = none) |
| `search_case_sensitive` | boolean | `false` | **NEW** — Case-sensitive filter |
| `search_regex` | boolean | `false` | **NEW** — Regex mode filter |
| `search_my_mentions` | boolean | `false` | **NEW** — Filter to messages mentioning user |
| `search_history` | boolean | `false` | **NEW** — Include database history |
| `search_error` | string/nil | `nil` | **NEW** — Inline error (e.g., invalid regex) |
| `search_last_query` | string | `""` | **NEW** — Remembered term for session re-open |

### 3. Window List (LiveView socket assign)

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `window_list` | list | `[]` | **NEW** — Ordered list of `{:status, nil}`, `{:channel, name}`, `{:pm, nick}` tuples |
| `window_index` | integer | `0` | **NEW** — Current position in window_list |

Computed from `@channels` and `@pm_conversations` assigns. Updated whenever channels/PMs change.

### 4. Custom Binding (persisted in user_preferences.key_bindings)

No schema change needed. The existing `key_bindings` JSON column in `user_preferences` table already stores a map of `action_string => %{"key" => ..., "modifiers" => [...]}`. New actions are automatically persisted when users customize them via the Options dialog.

## Relationships

```
KeyBindings.registry/1 ─── reads ──→ user_preferences.key_bindings (persisted)
                       ─── merges ──→ KeyBindings.defaults() (hardcoded)
                       ─── outputs ──→ Cheatsheet dialog (read-only display)
                       ─── outputs ──→ ShortcutDispatcherHook (JS binding map)
                       ─── outputs ──→ Options Key Bindings panel (editable)

SearchState ─── drives ──→ SearchBar component (UI controls)
            ─── drives ──→ SearchHighlightHook (client-side DOM manipulation)
            ─── queries ──→ Search.search_messages/3 (when history enabled)

WindowList ─── computed from ──→ @channels + @pm_conversations
           ─── indexed by ──→ navigation shortcuts (next/prev/1-9)
           ─── triggers ──→ switch_channel / switch_pm / switch_to_status events
```

## State Transitions

### Search State Machine

```
CLOSED ──[Ctrl+Shift+F]──→ OPEN (empty, last_query pre-filled)
OPEN ──[type query]──→ SEARCHING (debounce 300ms, then highlight)
SEARCHING ──[results found]──→ NAVIGATING (index=1, counter shows "1 of N")
NAVIGATING ──[↓/Next]──→ NAVIGATING (index++, wrap at N→1)
NAVIGATING ──[↑/Prev]──→ NAVIGATING (index--, wrap at 1→N)
NAVIGATING ──[toggle filter]──→ SEARCHING (re-execute with new flags)
NAVIGATING ──[clear query]──→ OPEN (highlights removed)
ANY ──[Escape/close]──→ CLOSED (highlights removed, query saved to last_query)
ANY ──[channel switch]──→ CLOSED (search resets for new channel)
```

### Cheatsheet State Machine

```
CLOSED ──[Ctrl+Shift+/]──→ OPEN
OPEN ──[Escape/X button]──→ CLOSED (focus returns to chat input)
OPEN ──[Ctrl+Shift+/]──→ CLOSED (toggle behavior)
```
