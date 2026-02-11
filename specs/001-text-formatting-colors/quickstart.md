# Quickstart: Text Formatting & Colors

**Feature Branch**: `001-text-formatting-colors`

## Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+ running
- Project dependencies installed (`make setup`)
- On branch `001-text-formatting-colors`

## Development Workflow

### 1. Run existing tests (confirm green baseline)

```bash
make test
```

### 2. Key files to create/modify

**New files** (domain layer):
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/formatter.ex` — mIRC format code parser
- `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs` — Formatter tests

**New files** (web layer):
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/formatting_toolbar.ex` — Toolbar component
- `apps/retro_hex_chat_web/assets/js/hooks/format_hook.js` — Keyboard shortcut hook
- `apps/retro_hex_chat_web/assets/js/hooks/format_toolbar_hook.js` — Toolbar interaction hook

**Modified files** (domain layer):
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` — Add `strip_formatting` field
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/policy.ex` — Extend `validate_content/1`

**Modified files** (web layer):
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — Template + handlers
- `apps/retro_hex_chat_web/assets/js/app.js` — Register new hooks
- `apps/retro_hex_chat_web/assets/css/dark-theme.css` — Formatting + toolbar CSS classes

### 3. Implementation order

1. `Chat.Formatter` module + tests (pure function, no dependencies)
2. `Chat.Policy` extension + tests
3. `Accounts.Session` extension + tests
4. CSS classes for formatting
5. ChatLive template changes (render formatted messages)
6. `FormatHook` JS (keyboard shortcuts)
7. `FormattingToolbar` component + `FormatToolbarHook` JS
8. ChatLive strip-formatting toggle
9. Integration / E2E tests

### 4. Verify

```bash
make test          # All tests green
make lint          # Format + Credo + Dialyzer clean
make server        # Manual verification at localhost:4000
```

## Testing Strategy

- **Unit tests**: `Chat.Formatter` — property-based with StreamData for parser edge cases
- **Unit tests**: `Chat.Policy` — format-only message rejection
- **Unit tests**: `Accounts.Session` — toggle_strip_formatting
- **LiveView tests**: ChatLive — formatted message rendering, strip toggle, toolbar presence
- **E2E tests**: Full send/receive with formatting, toolbar interaction
