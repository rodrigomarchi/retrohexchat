# Quickstart: Highlight / Mentions

**Feature**: 004-highlight-mentions
**Date**: 2026-02-11

## Prerequisites

- Existing RetroHexChat dev environment (`make setup` completed)
- Branch: `004-highlight-mentions`
- All existing tests passing (`make test`)
- All linters clean (`make lint`)

## Implementation Order

### 1. Domain Layer First (no web dependencies)

```bash
# Start with the matching engine — pure functions, easy to TDD
# File: apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight.ex
# Test: apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_test.exs

# Key function:
# Chat.Highlight.check(content, own_nick, highlight_words, sender_nick)
#   → {:highlight, color} | :no_highlight

# Test cases (write first):
# - Own nick match → {:highlight, default_color}
# - Case-insensitive → {:highlight, _}
# - Partial word → :no_highlight
# - Self-message → :no_highlight
# - Nick inside URL → :no_highlight
# - Custom word match → {:highlight, word_color}
# - Multiple matches → highest priority wins
# - Empty content → :no_highlight
# - System message type excluded (handled in ChatLive, not engine)
```

### 2. HighlightWord Struct + HighlightWords CRUD

```bash
# File: apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_word.ex
# File: apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_words.ex
# Test: apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_words_test.exs

# Pure in-memory CRUD — no database yet
# Pattern: identical to NotifyList/ContactList/NickColors
```

### 3. Session Extension

```bash
# File: apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex (modify)
# Add: highlight_words field, set_highlight_words/2, get_highlight_words/1
```

### 4. CSS Styling

```bash
# File: apps/retro_hex_chat_web/assets/css/dark-theme.css (modify)
# Add: .chat-message--highlighted, .tree-highlight, @keyframes tree-flash
```

### 5. ChatLive Integration

```bash
# File: apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex (modify)
# Modify: handle_info for new_message — add highlight check
# Add: highlight_channels assign, clearing on switch
# Add: push_event for sound
# Add: template changes for highlight class
```

### 6. TreeBar Flash

```bash
# File: apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex (modify)
# Add: highlight_channels attr, tree-highlight class logic
```

### 7. Persistence (migration + schema + save/load)

```bash
# File: apps/retro_hex_chat/priv/repo/migrations/*_create_highlight_words.exs (new)
# File: apps/retro_hex_chat/lib/retro_hex_chat/accounts/highlight_word_entry.ex (new)
# File: apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_words.ex (add save/load)
# Modify: ChatLive handle_info for nickserv_identified — load highlight words
```

### 8. Configuration Dialog

```bash
# File: apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/highlight_dialog.ex (new)
# File: apps/retro_hex_chat_web/test/.../components/highlight_dialog_test.exs (new)
# Modify: ChatLive — add dialog events and template inclusion
```

### 9. E2E Tests

```bash
# File: apps/retro_hex_chat_web/test/.../live/chat_live_highlight_test.exs (new)
# Full flow: connect → receive mention → see highlight → check flash → check sound
```

## Verification Commands

```bash
# After each step:
mix test                          # All tests pass
mix format --check-formatted      # Formatted
mix credo --strict                # No warnings
mix dialyzer                      # No type errors

# Full verification:
make ci                            # Full CI validation (9 parallel checks)
make lint                         # format + credo + dialyzer
```

## Key Integration Points

| What | Where | How |
|------|-------|-----|
| Highlight check | ChatLive `handle_info(:new_message)` | Call `Chat.Highlight.check/4` before `stream_insert` |
| Flash tracking | ChatLive assign `highlight_channels` | MapSet, add on highlight in non-active channel |
| Flash clearing | ChatLive `handle_event("switch_channel")` | `MapSet.delete(highlight_channels, channel)` |
| Sound trigger | ChatLive `handle_info(:new_message)` | `push_event(socket, "play_sound", %{type: "mention"})` |
| Persistence load | ChatLive `handle_info(:nickserv_identified)` | `HighlightWords.load(nick)` alongside existing loads |
| Persistence save | ChatLive highlight event handlers | `maybe_persist_highlight_words(socket, session)` |
| Dialog toggle | ChatLive `handle_event("open/close_highlight_dialog")` | `assign(socket, show_highlight_dialog: bool)` |

## Existing Code to Reuse

- `Chat.Formatter.strip/1` — strip formatting codes before matching
- `SoundHook` — play "mention" sound (no new JS needed)
- `NickColors.hex_for_index/1` — convert IRC color index to CSS hex
- `FormatToolbar` color picker pattern — reuse for highlight word color selection
- `NotifyList`/`ContactList` persistence pattern — save/load/maybe_persist helpers
- `AddressBookDialog` component pattern — dialog shell with retro design system chrome
