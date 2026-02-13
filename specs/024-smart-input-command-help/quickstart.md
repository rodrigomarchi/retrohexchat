# Quickstart: Smart Input & Command Help

**Feature**: 024-smart-input-command-help
**Date**: 2026-02-13

## Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+ running (via Docker: `make setup`)
- Node.js (for esbuild asset compilation)
- Development server: `make server` → http://localhost:4000

## Branch

```bash
git checkout 024-smart-input-command-help
```

## Key Files to Modify

### Domain Layer (`apps/retro_hex_chat/`)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat/commands/handler.ex` | Add `syntax_definition/0` optional callback |
| `lib/retro_hex_chat/commands/command_syntax.ex` | **NEW** — CommandSyntax, Parameter, SubOption structs |
| `lib/retro_hex_chat/commands/registry.ex` | Aggregate syntax definitions at compile time |
| `lib/retro_hex_chat/commands/handlers/*.ex` | Add `syntax_definition/0` to handlers (start with mode, kick, join, msg, ban) |
| `lib/retro_hex_chat/chat/user_preferences.ex` | Add `command_help_level` to display category |
| `lib/retro_hex_chat/chat/help_topics/features.ex` | Add help topics for new features |
| `lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex` | Update with new shortcuts |

### Web Layer (`apps/retro_hex_chat_web/`)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat_web/live/chat_live.html.heex` | Replace `<input>` with `<textarea>`, add tooltip component, dynamic placeholder |
| `lib/retro_hex_chat_web/live/chat_live.ex` | Add tooltip assigns, placeholder computation |
| `lib/retro_hex_chat_web/live/chat_live/core_events.ex` | Handle `syntax_tooltip_query`, `syntax_tooltip_dismiss` events |
| `lib/retro_hex_chat_web/live/chat_live/options_events.ex` | Handle `update_command_help_level` event |
| `lib/retro_hex_chat_web/components/syntax_tooltip.ex` | **NEW** — Tooltip function component |
| `lib/retro_hex_chat_web/components/history_search.ex` | **NEW** — Ctrl+R inline search component |
| `lib/retro_hex_chat_web/components/options_dialog.ex` | Add command help level setting to Display panel |
| `assets/js/hooks/autocomplete_hook.js` | Extend for textarea, tooltip triggers, Ctrl+Up/Down/R |
| `assets/js/hooks/input_history_hook.js` | **NEW** — Enhanced history with localStorage persistence |
| `assets/js/hooks/input_resize_hook.js` | **NEW** — Textarea auto-resize logic |
| `assets/css/chat.css` | Textarea styling, tooltip CSS |

### Tests

| File | Purpose |
|------|---------|
| `test/retro_hex_chat/commands/command_syntax_test.exs` | **NEW** — Unit tests for syntax structs |
| `test/retro_hex_chat/chat/user_preferences_test.exs` | Add tests for `command_help_level` |
| `test/retro_hex_chat_web/live/chat_live/syntax_tooltip_test.exs` | **NEW** — LiveView tests for tooltip |
| `test/retro_hex_chat_web/live/chat_live/smart_input_test.exs` | **NEW** — LiveView tests for placeholder, textarea |
| `test/retro_hex_chat_web/live/chat_live/enhanced_history_test.exs` | **NEW** — LiveView tests for history events |

## Development Workflow

### Step 1: Domain — CommandSyntax structs + Handler callback

```bash
# Write tests first
mix test test/retro_hex_chat/commands/command_syntax_test.exs

# Then implement
# 1. Create CommandSyntax, Parameter, SubOption structs
# 2. Add syntax_definition/0 as optional callback in Handler
# 3. Add syntax definitions to 5-6 key handlers
# 4. Extend Registry to aggregate syntax data
```

### Step 2: Preferences — Add command_help_level

```bash
mix test test/retro_hex_chat/chat/user_preferences_test.exs
# Add command_help_level to display defaults and validation
```

### Step 3: Web — Textarea conversion + placeholder

```bash
# 1. Replace <input> with <textarea> in template
# 2. Add dynamic placeholder based on active context
# 3. Create input_resize_hook.js for auto-grow
# 4. Update CSS for textarea styling
# 5. Update autocomplete_hook.js for Enter/Shift+Enter
```

### Step 4: Web — Syntax tooltip

```bash
# 1. Create syntax_tooltip.ex component
# 2. Add event handlers for tooltip query/dismiss
# 3. Extend autocomplete_hook.js for tooltip triggers
# 4. Add tooltip CSS
```

### Step 5: Web — Enhanced history

```bash
# 1. Create input_history_hook.js
# 2. Implement Ctrl+Up/Down with draft preservation
# 3. Implement Ctrl+R reverse search
# 4. Add localStorage persistence with sensitive filtering
# 5. Create history_search.ex component for inline UI
```

### Step 6: Help topics + Settings UI

```bash
# 1. Add help topics to features.ex and keyboard_shortcuts.ex
# 2. Add command_help_level setting to options_dialog.ex
```

## Validation

```bash
# Compile first
mix compile --warnings-as-errors

# Then in parallel:
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Architecture Notes

- **No database migrations needed** — preferences use JSON column, syntax data is compile-time.
- **Textarea replaces input** — all hooks that reference `#chat-input` must be verified.
- **Client-side history coexists with server-side** — existing Up/Down behavior unchanged.
- **Tooltip is server-rendered content, client-positioned** — follows autocomplete pattern.
