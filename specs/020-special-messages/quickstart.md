# Quickstart: Special Messages

**Feature Branch**: `020-special-messages`
**Date**: 2026-02-13

## Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+ running with existing schema
- `mix deps.get && mix compile` passing
- Docker for PostgreSQL (via `make setup`)

## Implementation Order

### Phase 1: Foundation — Server Roles & Configuration

1. **Create `Accounts.ServerRoles`** — New module with `admin?/2`, `server_operator?/2` functions reading from application config
2. **Add config entries** — Add `:admins` and `:server_operators` lists to `config.exs` (empty by default), `dev.exs` (with test values)
3. **Modify `Accounts.Session`** — Add `user_modes: MapSet.t()` and `welcomed_channels: MapSet.t()` fields with helper functions (`has_mode?/2`, `set_mode/2`, `unset_mode/2`, `add_welcomed_channel/2`, `welcomed_channel?/2`)
4. **Modify `Commands.Handler`** — Add `is_admin` and `is_server_operator` to context type

### Phase 2: Database & Schemas

5. **Create migration** — `server_settings` table (key-value pattern for MOTD)
6. **Create migration** — `channel_welcome_messages` table
7. **Create `Services.ServerSetting`** — Ecto schema and changeset
8. **Create `Services.ChannelWelcomeMessage`** — Ecto schema and changeset
9. **Extend `Services.Queries`** — Add query functions for settings and welcome messages

### Phase 3: Domain Services

10. **Create `Services.Motd`** — MOTD management module with in-memory cache, `get/0`, `set/2`, `clear/1`
11. **Modify `Channels.Server`** — Load welcome message on init, add `set_welcome/3`, `clear_welcome/2`, `get_welcome/1` functions, add `welcome_message` to state

### Phase 4: Command Handlers (P1 — MOTD)

12. **Create `Commands.Handlers.SetMotd`** — Admin-only, sets MOTD via `Motd.set/2`
13. **Create `Commands.Handlers.ClearMotd`** — Admin-only, clears MOTD via `Motd.clear/1`
14. **Create `Commands.Handlers.Motd`** — Any user, reads MOTD via `Motd.get/0`

### Phase 5: Command Handlers (P2 — Welcome Messages)

15. **Create `Commands.Handlers.SetWelcome`** — Channel operator+, sets welcome via Server
16. **Create `Commands.Handlers.ClearWelcome`** — Channel operator+, clears welcome via Server

### Phase 6: Command Handlers (P3 — Wallops & User Modes)

17. **Create `Commands.Handlers.Umode`** — User mode management (+w/-w)
18. **Create `Commands.Handlers.Wallops`** — Server operator+, broadcasts to "server:wallops"

### Phase 7: Command Handlers (P4 — Announcements)

19. **Create `Commands.Handlers.Announce`** — Admin-only, broadcasts to "server:announcements"

### Phase 8: Registry & Context

20. **Modify `Commands.Registry`** — Register all 8 new commands
21. **Modify `CommandDispatch`** — Add `is_admin` and `is_server_operator` to context builder

### Phase 9: Web Layer — PubSub & UI Actions

22. **Create `PubSubHandlers.ServerMessages`** — Handle `:announcement`, `:wallops`, `:motd_updated` events
23. **Modify `PubSubHandlers` router** — Route new event types to ServerMessages
24. **Create `UiActions.ServerMessages`** — Handle `:show_motd`, `:set_welcome`, `:clear_welcome`, `:set_user_mode` actions
25. **Modify `UiActionHandlers` router** — Route new UI actions to ServerMessages

### Phase 10: Web Layer — Mount & Join Flow

26. **Modify ChatLive mount** — Subscribe to new PubSub topics, display MOTD on connect
27. **Modify helpers/channel.ex join_channel** — Display welcome message on channel join with deduplication logic

### Phase 11: CSS & Styling

28. **Add CSS styles** — MOTD bordered container, announcement bold+colored background, wallops italic styling

### Phase 12: Help System

29. **Add help topics** — 9 new topics: /motd, /setmotd, /clearmotd, /setwelcome, /clearwelcome, /wallops, /announce, /umode, "Special Messages" feature overview
30. **Update existing topics** — Add new commands to the commands overview topic

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

## Key Files

```text
# Domain layer — NEW
apps/retro_hex_chat/lib/retro_hex_chat/accounts/server_roles.ex
apps/retro_hex_chat/lib/retro_hex_chat/services/server_setting.ex
apps/retro_hex_chat/lib/retro_hex_chat/services/channel_welcome_message.ex
apps/retro_hex_chat/lib/retro_hex_chat/services/motd.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/set_motd.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/clear_motd.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/motd.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/set_welcome.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/clear_welcome.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/wallops.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/announce.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/umode.ex

# Domain layer — MODIFY
apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex
apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex
apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex
apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex
apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex  (or submodule)

# Migrations — NEW
apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_server_settings.exs
apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_channel_welcome_messages.exs

# Web layer — NEW
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/server_messages.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/server_messages.ex

# Web layer — MODIFY
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_action_handlers.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex

# CSS — MODIFY
apps/retro_hex_chat_web/assets/css/  (status or messages CSS file)

# Tests — NEW
apps/retro_hex_chat/test/retro_hex_chat/accounts/server_roles_test.exs
apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs  (extend)
apps/retro_hex_chat/test/retro_hex_chat/services/motd_test.exs
apps/retro_hex_chat/test/retro_hex_chat/services/server_setting_test.exs
apps/retro_hex_chat/test/retro_hex_chat/services/channel_welcome_message_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/set_motd_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/clear_motd_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/motd_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/set_welcome_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/clear_welcome_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/wallops_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/announce_test.exs
apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/umode_test.exs
apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/special_messages_test.exs
```
