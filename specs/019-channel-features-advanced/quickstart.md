# Quickstart: Channel Features Advanced

**Feature Branch**: `019-channel-features-advanced`
**Date**: 2026-02-13

## Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+ running with existing schema
- `mix deps.get && mix compile` passing
- Docker for PostgreSQL (via `make setup`)

## Implementation Order

### Phase 1: Core Domain — Extended Hierarchy (P1)

1. **Modify `Channels.Membership`** — Add `:owner` and `:half_operator` to role type, add `rank/1`, `owners/1`, `half_operators/1`, `outranks?/3` functions
2. **Modify `Channels.Policy`** — Add `can_kick?/3`, `can_ban?/2`, `can_set_mode?/3` with rank-based checks
3. **Modify `Channels.Modes`** — Add `join_throttle` field, new flag atoms and character mappings, mutual exclusivity validation, predicate functions
4. **Modify `Channels.Server`** — Update `determine_join_role/2` (first joiner → `:owner`), update `set_mode/4` with rank checks, update `kick/4` and `ban/4`, add `join_timestamps` state field, add `knock/3` function, update `apply_user_modes/3` for +q/+h, update `send_message/4` for +c/+n, update `join` for +R/+j

### Phase 2: Database Migration

5. **Create migration** — `ALTER TABLE registered_channels ADD COLUMN mode_join_throttle VARCHAR(20)`
6. **Update `RegisteredChannel` schema** — Add `mode_join_throttle` field
7. **Update persistence** — Load/save join_throttle in `load_persisted_state/1` and mode persistence callbacks

### Phase 3: Command Handlers

8. **Create `Commands.Handlers.Knock`** — New handler implementing Handler behaviour
9. **Modify `Commands.Handlers.Mode`** — Update permission check (half-op can only +v/-v)
10. **Modify `Commands.Handlers.Kick`** — Support half-op check via `half_operator_in`
11. **Modify `Commands.Handlers.Ban`** — Ensure only operator+ can ban
12. **Register `/knock`** in command registry

### Phase 4: Web Layer

13. **Modify Nicklist component** — 5 groups with prefixes (~, @, %, +)
14. **Modify ChannelState PubSub handler** — Handle +q, +h, -q, -h mode changes
15. **Add Knock PubSub handler** — Display knock notifications to operators/owners
16. **Modify ChannelListLive** — Filter secret/private channels based on viewer membership
17. **Modify Whois helper** — Filter secret channels from whois output
18. **Modify CommandDispatch** — Expand `operator_in` to include owners, add `half_operator_in`
19. **Add `:knock_channel` UI action** with rate limiting

### Phase 5: Help System

20. **Add help topics** — +q (Owner), +h (Half-Operator), +n (No External), +s (Secret), +p (Private), +c (Strip Colors), +R (Registered Only), +j (Join Throttle), +K (No Knock), /knock command
21. **Update channel modes overview** — Include new modes in the overview topic

## Verification

```bash
# Compile with warnings as errors
mix compile --warnings-as-errors

# Run all checks in parallel
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Key Files to Modify

```text
# Domain layer
apps/retro_hex_chat/lib/retro_hex_chat/channels/membership.ex
apps/retro_hex_chat/lib/retro_hex_chat/channels/modes.ex
apps/retro_hex_chat/lib/retro_hex_chat/channels/policy.ex
apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex
apps/retro_hex_chat/lib/retro_hex_chat/channels/queries.ex
apps/retro_hex_chat/lib/retro_hex_chat/services/registered_channel.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/knock.ex    (NEW)
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/mode.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/kick.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ban.ex
apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/channel_modes.ex

# Web layer
apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/channel_list_live.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/whois.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/core.ex

# Migration
apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_add_advanced_channel_modes.exs (NEW)

# Tests (NEW)
apps/retro_hex_chat/test/retro_hex_chat/channels/membership_test.exs
apps/retro_hex_chat/test/retro_hex_chat/channels/modes_test.exs
apps/retro_hex_chat/test/retro_hex_chat/channels/policy_test.exs
apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/knock_test.exs
apps/retro_hex_chat_web/test/retro_hex_chat_web/components/nicklist_test.exs
apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_live_test.exs
```
