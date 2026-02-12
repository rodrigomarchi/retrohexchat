# Quickstart: Scripting & Aliases (Simplified)

**Feature**: 018-scripting-aliases
**Date**: 2026-02-12

## Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+ running (via Docker: `make setup`)
- Dependencies installed: `mix deps.get`

## Database Setup

Run the 3 new migrations:

```bash
mix ecto.migrate
```

This creates:
- `aliases` table — stores user-defined command aliases
- `custom_menu_items` table — stores custom context menu entries
- `autorespond_rules` table — stores auto-respond event rules

## New Modules Overview

### Domain Layer (`apps/retro_hex_chat/lib/retro_hex_chat/`)

| Module | Purpose |
|--------|---------|
| `Chat.AliasExpander` | Pure variable expansion engine ($1, $nick, $chan) |
| `Chat.AliasList` | Alias CRUD + persistence (follows PerformList pattern) |
| `Chat.AliasEntry` | Value object for a single alias |
| `Chat.CustomMenus` | Custom menu item CRUD + persistence |
| `Chat.CustomMenuItem` | Value object for a single menu item |
| `Chat.AutoRespondRules` | Auto-respond rule CRUD + persistence |
| `Chat.AutoRespondRule` | Value object for a single rule |
| `Chat.TimerManager` | Timer validation and formatting (pure functions) |
| `Chat.Schemas.AliasEntry` | Ecto schema for `aliases` table |
| `Chat.Schemas.CustomMenuItem` | Ecto schema for `custom_menu_items` table |
| `Chat.Schemas.AutoRespondRule` | Ecto schema for `autorespond_rules` table |
| `Commands.Handlers.Alias` | `/alias` command handler |
| `Commands.Handlers.Timer` | `/timer` command handler |
| `Commands.Handlers.Popups` | `/popups` command handler |
| `Commands.Handlers.AutoRespond` | `/autorespond` command handler |

### Web Layer (`apps/retro_hex_chat_web/lib/retro_hex_chat_web/`)

| Module | Purpose |
|--------|---------|
| `Components.AliasDialog` | Alias Editor dialog (98.css styled) |
| `Components.CustomMenusDialog` | Custom Menus editor dialog |
| `Components.AutoRespondDialog` | Auto-Respond editor dialog |

### Modified Existing Files

| File | Changes |
|------|---------|
| `Accounts.Session` | 3 new fields: `aliases`, `custom_menus`, `autorespond_rules` |
| `Commands.Registry` | 4 new entries: `alias`, `timer`, `popups`, `autorespond` |
| `ChatLive` | Alias interception in dispatch, timer handle_info, dialog events, auto-respond in event handlers, menu items in template, persistence |
| `Components.MenuBar` | 3 new Tools menu entries |
| `Components.ContextMenu` | Custom menu items appended after separator |
| `Components.TreebarContextMenu` | Custom menu items appended after separator |
| `Chat.HelpTopics` | New help topics for all 4 commands + features |

## Running Tests

```bash
# Unit tests for domain modules
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/alias_list_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/alias_expander_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/custom_menus_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/auto_respond_rules_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/timer_manager_test.exs

# Command handler tests
mix test apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/alias_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/timer_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/popups_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/auto_respond_test.exs

# LiveView integration tests
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_alias_test.exs

# Full suite
mix test --include e2e
```

## Validation Pipeline

```bash
# 1. Compile first
mix compile --warnings-as-errors

# 2. Then in parallel
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Key Architecture Decisions

1. **Alias interception** happens in `dispatch_command/4` in ChatLive, BEFORE `Dispatcher.dispatch/3` — because aliases are per-user session state
2. **Timers** use `Process.send_after/3` in the LiveView process — they die automatically on disconnect
3. **Variable expansion** is centralized in `AliasExpander` — shared by aliases, custom menus, auto-respond, and timers
4. **Persistence** follows the established pattern: `Task.start(fn -> Module.save(nick, data) end)` for registered users
5. **No new OTP processes** — everything runs in the existing LiveView process, consistent with the feature's lightweight nature
