# Quickstart: Miscellaneous Polish (022)

**Branch**: `022-misc-polish`

## Prerequisites

```bash
git checkout 022-misc-polish
make setup    # if not already done
make server   # verify clean start at localhost:4000
make test     # verify 0 failures baseline
make lint     # verify clean linters
```

## Implementation Order

The 11 user stories are organized into 7 phases. Each phase is independently testable and deliverable.

### Phase 1: Nick Column Alignment (US1) — P1
**Files**: `chat_live.html.heex`, `chat.css`, `dark-theme.css`
- Add CSS grid to regular message layout (3 columns: timestamp, nick, content)
- Fixed-width nick column accommodating 16 characters
- Action/notice/system messages keep full-width layout
- **Test**: Messages from short and long nicks align at same content offset

### Phase 2: Double-Click Actions (US2) — P1
**Files**: `nicklist.ex`, `context_menu_events.ex`, `scroll_hook.js` or new hook, `chat_live.html.heex`
- Nicklist double-click → open PM (modify existing 300ms detection from whois to PM query)
- Channel names in chat → add `data-channel` spans, handle dblclick
- URLs → already clickable via `<a>` tags (verify single-click opens)
- **Test**: Double-click nick in nicklist opens PM tab

### Phase 3: Right-Click Copy (US3) — P1
**Files**: New `chat_copy_hook.js`, `chat_live.html.heex`, `chat.css`
- JS hook on `.chat-messages` for `contextmenu` event
- 98.css styled context menu with "Copy" item
- Clipboard API for plain text copy
- Disabled state when no selection
- **Test**: Select text, right-click, Copy → clipboard contains selected text

### Phase 4: Input Enhancements (US4 + US5) — P2
**Files**: New `char_counter_hook.js`, new `paste_hook.js`, new `paste_confirm_dialog.ex`, `chat_live.html.heex`, `chat.css`, ChatLive event handlers
- Character counter: JS hook updates counter span, `maxlength="1000"` for hard cap
- Multi-line paste: JS paste event → LiveView dialog → 300ms paced send
- Paste dialog: 98.css component with line count, flood warning, send/cancel
- **Test**: Type → counter updates. Paste 5 lines → dialog appears.

### Phase 5: Server Features (US6 + US7) — P2
**Files**: `helpers/channel.ex`, `helpers/session.ex`, `pubsub_handlers/messages.ex`, ChatLive assigns, `options_events.ex`, `user_preferences.ex`
- Quit broadcast: Add quit message to all channels during cleanup
- Away auto-reply: MapSet tracking in assigns, check on PM receive, send once per sender
- Quit message preference: Add to UserPreferences display settings
- **Test**: User A quits → User B sees quit message. Away user gets PM → sender sees auto-reply once.

### Phase 6: Timestamp Format (US8) — P3
**Files**: `chat_live.ex` (format_time), `options_dialog.ex`, `user_preferences.ex`, `chat_live.html.heex`
- Add timestamp_format to UserPreferences display settings
- Add format selector to Options Dialog display panel
- Modify `format_time/1` to accept format from session preferences
- Stream reset on format change
- **Test**: Change format in Options → all messages update immediately

### Phase 7: Emoji + About + Help (US9 + US10 + US11) — P3
**Files**: New `emoji_data.ex`, new `emoji_picker.ex`, new `emoji_picker_hook.js`, new `about_dialog.ex`, `menu_bar.ex`, `help_events.ex`, `help_topics.ex` submodules, `chat_live.html.heex`
- Emoji: Static data module, picker component, toolbar button, JS insertion hook
- About: Dedicated component with ASCII art logo, replacing inline HTML
- Help menu: "IRC Commands" and "Keyboard Shortcuts" items opening help at topic
- Help topics: Add topics for all new features (nick alignment, copy, paste, counter, quit, away, emoji, timestamps)
- **Test**: Open emoji picker, click emoji → inserted in input. Help > IRC Commands → opens help.

## CI Validation

After each phase:
```bash
mix compile --warnings-as-errors
# Then in parallel:
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Key Files Reference

| Area | File |
|------|------|
| Chat template | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` |
| Chat CSS | `apps/retro_hex_chat_web/assets/css/chat.css` |
| Dark theme | `apps/retro_hex_chat_web/assets/css/dark-theme.css` |
| JS hooks | `apps/retro_hex_chat_web/assets/js/hooks/` |
| Hook index | `apps/retro_hex_chat_web/assets/js/hooks/index.js` |
| ChatLive | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` |
| Options Dialog | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` |
| Options Events | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex` |
| UserPreferences | `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` |
| Help Topics | `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` |
| Menu Bar | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` |
| Components | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/` |
