# Quickstart: Flood Protection (013)

**Feature**: 013-flood-protection
**Date**: 2026-02-12

## Prerequisites

- Elixir 1.17+ / OTP 27+ installed
- PostgreSQL 16+ running
- Project dependencies installed (`mix deps.get`)
- Database created and migrated (`mix ecto.setup`)

## Setup

### 1. Run the new migration

```bash
cd apps/retro_hex_chat
mix ecto.migrate
```

This creates the `flood_protection_settings` table.

### 2. Start the dev server

```bash
make server
```

### 3. Verify

1. Navigate to `http://localhost:4000`
2. Connect with a nickname
3. Open **Tools > Flood Protection** from the menu bar
4. Verify the settings dialog shows default values:
   - Flood threshold: 10 messages
   - Flood window: 15 seconds
   - Auto-ignore duration: 5 minutes
   - Spam threshold: 3 duplicates
   - Spam window: 10 seconds
   - CTCP reply limit: 2 replies
   - CTCP reply window: 10 seconds

## Testing

### Run all tests

```bash
make test
```

### Run only flood protection tests

```bash
# Unit tests (domain logic)
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/flood_protection_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/flood_tracker_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/duplicate_tracker_test.exs

# Integration tests (DB persistence)
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/schemas/flood_protection_setting_test.exs

# LiveView tests (dialog + filtering)
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_flood_test.exs
```

### Run static analysis

```bash
make lint
```

## Key Files

| File | Purpose |
|------|---------|
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/flood_protection.ex` | Settings CRUD + save/load |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/flood_tracker.ex` | Per-sender flood detection |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/duplicate_tracker.ex` | Duplicate message detection |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/flood_protection_setting.ex` | Ecto schema |
| `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` | Session struct (extended) |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/flood_protection_dialog.ex` | Settings dialog |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` | LiveView integration |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` | Help documentation |

## Manual Testing Scenarios

### Duplicate detection
1. Open two browser windows, connect as User A and User B in the same channel
2. As User B, send the same message 3 times quickly (within 10 seconds)
3. Verify: User A sees only the first 2 messages; the 3rd is silently dropped

### Auto-ignore
1. As User B, send 10+ different messages within 15 seconds
2. Verify: User A sees a system message "* UserB has been auto-ignored for flooding (5 minutes)"
3. Verify: Further messages from User B are not displayed to User A
4. Wait 5 minutes (or adjust settings to shorter duration for testing)
5. Verify: Messages from User B appear again

### CTCP flood protection
1. As User A, send `/ctcp UserB VERSION` rapidly (5+ times in 10 seconds)
2. Verify: User A only receives 2 CTCP replies; the rest are silently dropped by User B's client

### Settings persistence
1. Register and identify as a user
2. Open Tools > Flood Protection, change a threshold, save
3. Disconnect and reconnect
4. Open the dialog again — verify the changed threshold persisted
