# Quickstart: Notice System

**Feature**: 011-notice-system
**Date**: 2026-02-12

## Prerequisites

- Elixir 1.17+ / OTP 27+ installed
- PostgreSQL 16+ running (via Docker or native)
- Project dependencies installed (`mix deps.get`)
- Database set up (`mix ecto.setup`)

## Setup

```bash
# Switch to the feature branch
git checkout 011-notice-system

# Install any new dependencies (none expected for this feature)
mix deps.get

# Run the new migration for notice_routing_settings table
mix ecto.migrate

# Verify everything compiles
mix compile --warnings-as-errors

# Run static analysis
mix format --check-formatted && mix credo --strict
```

## Development Workflow

### 1. Run Tests

```bash
# Run all tests
make test

# Run only unit tests (fast feedback)
mix test --only unit

# Run only notice-related tests
mix test test/retro_hex_chat/commands/handlers/notice_test.exs
mix test test/retro_hex_chat/commands/handlers/notice_routing_test.exs
mix test test/retro_hex_chat/chat/notice_routing_test.exs
mix test test/retro_hex_chat_web/live/chat_live_notice_test.exs
```

### 2. Start Dev Server

```bash
make server
# Visit http://localhost:4000
```

### 3. Manual Testing

1. Open two browser windows, connect as different users (e.g., "Alice" and "Bob")
2. Both users join `#test` channel
3. As Alice, type: `/notice Bob Hey, check this out`
4. Verify Bob sees `-Alice- Hey, check this out` with notice styling in active window
5. As Bob, type: `/notice #test Channel announcement`
6. Verify all members see the notice in the channel window
7. As Bob, type: `/notice_routing status` then have Alice send another notice
8. Verify the notice appears in Bob's status tab
9. Verify NO PM windows are created
10. Verify NO notification sounds are played

## Key Files

| File | Purpose |
|------|---------|
| `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/notice.ex` | `/notice` command handler |
| `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/notice_routing.ex` | `/notice_routing` command handler |
| `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` | Command registration |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/notice_routing.ex` | Domain module for routing settings |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/notice_routing_setting.ex` | Ecto schema |
| `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` | Session struct (notice_routing field) |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex` | Extended with :notices type |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex` | Extended with :notice matching |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` | PubSub handlers + dispatch |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex` | Notice rendering |
| `apps/retro_hex_chat_web/assets/css/layout.css` | .chat-notice CSS |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` | Help documentation |

## Static Analysis

```bash
# Full lint suite
make lint

# Individual checks
mix format --check-formatted
mix credo --strict
mix dialyzer
```
