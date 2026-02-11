# Quickstart: Notify List (Buddy List)

**Feature**: 002-notify-list
**Date**: 2026-02-11

## Prerequisites

- Existing RetroHexChat dev environment (`make setup` completed)
- PostgreSQL 16+ running
- On branch `002-notify-list`

## New Dependencies

None. All implementation uses existing Elixir/Phoenix/Ecto stack.

## Database Setup

After creating the migration:

```bash
cd apps/retro_hex_chat && mix ecto.migrate
```

New tables: `notify_list_entries`, `notify_list_settings`

## Key Files to Know

### Domain Layer (apps/retro_hex_chat)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat/presence/notify_list.ex` | Core context: CRUD, persistence, whois aggregation |
| `lib/retro_hex_chat/accounts/session.ex` | Extended with notify_list and notify_settings fields |
| `lib/retro_hex_chat/commands/handlers/notify.ex` | `/notify` command handler |
| `lib/retro_hex_chat/commands/registry.ex` | Register new command |
| `lib/retro_hex_chat/services/nick_serv.ex` | Add identify broadcast |
| `priv/repo/migrations/*_create_notify_list_entries.exs` | DB migration |

### Web Layer (apps/retro_hex_chat_web)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat_web/live/chat_live.ex` | Integrate notify list, status window, global presence |
| `lib/retro_hex_chat_web/components/status_window.ex` | Status window function component |
| `lib/retro_hex_chat_web/components/notify_list_window.ex` | Notify List window function component |
| `assets/js/hooks/notify_list_hook.js` | Double-click handler for buddy list |

## Development Flow

### Phase 1: Domain Foundation
1. Write migration + schema
2. Implement `Presence.NotifyList` context (CRUD + persistence)
3. Extend `Session` struct
4. Write unit + integration tests

### Phase 2: Global Presence + Notifications
1. Add `"presence:global"` broadcasts in ChatLive mount/terminate
2. Implement debounce logic in ChatLive
3. Add NickServ identify broadcast
4. Wire notify list restoration on identify
5. Write integration tests

### Phase 3: UI — Status Window
1. Create `status_window.ex` component
2. Add `:status_messages` stream to ChatLive
3. Route notify events to Status window
4. Write LiveView tests

### Phase 4: UI — Notify List Window
1. Create `notify_list_window.ex` component
2. Wire add/remove/edit actions
3. Implement double-click to PM
4. Write LiveView tests

### Phase 5: Commands + Auto-Whois
1. Implement `/notify` command handler
2. Register in command registry
3. Implement whois data aggregation
4. Wire auto-whois toggle + display
5. Write command + e2e tests

## Testing

```bash
# Run all tests (excludes e2e)
make test

# Run only notify list tests
mix test test/retro_hex_chat/presence/notify_list_test.exs
mix test test/retro_hex_chat/commands/handlers/notify_test.exs
mix test test/retro_hex_chat_web/live/chat_live_notify_test.exs
mix test test/retro_hex_chat_web/live/chat_live_status_test.exs

# Run e2e tests
mix test --only e2e

# Linting
make lint
```

## Key Patterns to Follow

- **Command handlers**: See `commands/handlers/whois.ex` for the pattern
- **Function components**: See `components/treebar.ex` for MDI component pattern
- **PubSub broadcasts**: See existing `:user_joined` / `:user_left` patterns in ChatLive
- **Stream management**: See `:chat_messages` stream for Status window's `:status_messages`
- **Session updates**: See `Session.add_channel/2` for the pattern of extending Session
