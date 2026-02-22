# Quickstart: Channel Central Dialog

**Feature Branch**: `007-channel-central`
**Date**: 2026-02-11

## Prerequisites

- Elixir 1.17+ / OTP 27+
- Phoenix 1.8+ with LiveView 1.0+
- PostgreSQL 16+ running (Docker via `make setup`)
- All existing tests passing (`make test`)
- All linters clean (`make lint`)

## Setup

```bash
git checkout 007-channel-central
make setup    # ensure DB is up
mix deps.get
mix ecto.migrate
```

## Implementation Order

### Phase 1: Database & Domain Layer

1. **Migration**: Create `ban_exceptions` and `invite_exceptions` tables
2. **Ecto Schemas**: `Services.BanException` and `Services.InviteException`
3. **Service Queries**: CRUD functions in `Services.Queries`
4. **Server State Extension**: Add `topic_set_by`, `topic_set_at`, `ban_exceptions`, `invite_exceptions` to GenServer state
5. **Policy Extension**: Update `can_join?` to check exception lists
6. **Server API**: New public functions for exception management
7. **get_state Extension**: Return enriched state map

### Phase 2: UI Components

8. **ChannelCentralDialog Component**: retro tabbed dialog with 5 tabs
9. **Treebar Extension**: Double-click handler + context menu
10. **ChatLive Integration**: Assigns, event handlers, PubSub handlers
11. **Menu Bar**: Add Channel Central entry under Tools (or Channel) menu

### Phase 3: Real-Time & Polish

12. **Real-Time Updates**: PubSub handlers for exception events
13. **Operator/Non-Operator Views**: Conditional rendering based on role
14. **Help Topics**: Add feature documentation
15. **E2E Tests**: End-to-end coverage

## Key Files to Modify

### Domain App (`apps/retro_hex_chat/`)

| File | Changes |
|------|---------|
| `priv/repo/migrations/NEW_*` | Two new migration files |
| `lib/retro_hex_chat/services/ban_exception.ex` | New Ecto schema |
| `lib/retro_hex_chat/services/invite_exception.ex` | New Ecto schema |
| `lib/retro_hex_chat/services/queries.ex` | Add exception CRUD |
| `lib/retro_hex_chat/channels/server.ex` | Extend state, new API functions |
| `lib/retro_hex_chat/channels/policy.ex` | Extend can_join? with exceptions |
| `lib/retro_hex_chat/services/chan_serv.ex` | Cleanup exceptions on channel drop |
| `lib/retro_hex_chat/chat/help_topics.ex` | New help topics |

### Web App (`apps/retro_hex_chat_web/`)

| File | Changes |
|------|---------|
| `lib/.../components/channel_central_dialog.ex` | New component |
| `lib/.../components/tree_bar.ex` | Add dblclick + context menu |
| `lib/.../components/menu_bar.ex` | Add Channel Central menu item |
| `lib/.../live/chat_live.ex` | Assigns, events, PubSub handlers |
| `assets/css/layout.css` | Dialog CSS if needed |
| `assets/css/dark-theme.css` | Dark theme counterparts |

### Tests

| File | What it tests |
|------|---------------|
| `test/retro_hex_chat/services/queries_test.exs` | Exception CRUD |
| `test/retro_hex_chat/channels/server_test.exs` | Exception management, get_state |
| `test/retro_hex_chat/channels/policy_test.exs` | Exception bypass logic |
| `test/.../components/channel_central_dialog_test.exs` | Component rendering |
| `test/.../live/chat_live_test.exs` | Integration tests |
| `test/.../live/chat_live_e2e_test.exs` | E2E tests |

## Verification

```bash
make test          # All tests pass
make lint          # All linters clean
make test.all      # Including E2E
```
