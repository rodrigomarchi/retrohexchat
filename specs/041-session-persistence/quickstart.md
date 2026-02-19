# Quickstart: Session Persistence

## Prerequisites

- Docker running (PostgreSQL)
- `make setup` completed previously

## Development

```bash
make server              # Dev server at localhost:4000
```

## Testing

```bash
# Run all tests (recommended)
make test

# Run specific test files for this feature
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autojoin_auto_add_test.exs

# Full CI validation
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
mix test --include e2e
mix dialyzer
```

## Key Files to Modify

| File | Change |
|------|--------|
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex` | Add `list_pm_partners/2` |
| `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` | Modify `add_pm_conversation/2`, add `move_pm_to_front/2` |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex` | Add `restore_pm_conversations/2`, wire into `load_persisted_data/2` |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` | Auto-open PM conversation in `apply_new_pm/3` |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` | Auto-add/remove auto-join on join/part |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` | Add help topics |

## Manual Testing

1. **PM Restore**: Register & identify as User A. Send PMs to Users B, C, D. Refresh the page. Verify Private section shows B, C, D in recency order.
2. **PM Auto-Open**: As User A, have User E send you a PM. Verify E appears in treebar with unread badge + toast + sound.
3. **Auto-Join Add**: As identified user, `/join #test-channel`. Check auto-join list shows `#test-channel`.
4. **Auto-Join Remove**: `/part #test-channel`. Check auto-join list no longer shows `#test-channel`.
5. **Auto-Join Limit**: Fill auto-join to 20 entries. `/join #extra`. Verify join succeeds but system message warns about limit.
