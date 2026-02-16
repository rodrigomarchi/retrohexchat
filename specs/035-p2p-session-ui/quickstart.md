# Quickstart: 035-p2p-session-ui

## Prerequisites

- Feature 034 (P2P Foundation) merged and working
- Feature 032 (Notification System) merged and working
- Docker running (PostgreSQL)
- `make setup` completed

## Development Setup

```bash
git checkout 035-p2p-session-ui
make server  # localhost:4000
```

## Files to Create

### Domain Layer (retro_hex_chat)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat/commands/handlers/p2p.ex` | /p2p command handler |
| `lib/retro_hex_chat/commands/handlers/call.ex` | /call command handler |
| `lib/retro_hex_chat/commands/handlers/send_file.ex` | /sendfile command handler |

### Web Layer (retro_hex_chat_web)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat_web/live/p2p_session_live.ex` | P2P lobby LiveView |
| `lib/retro_hex_chat_web/components/p2p_lobby.ex` | Lobby UI components |

### Assets

| File | Purpose |
|------|---------|
| `assets/js/hooks/p2p_capability_hook.js` | Browser capability detection |
| `assets/js/hooks/p2p_session_hook.js` | beforeunload + cleanup |
| `assets/js/lib/p2p.js` | P2P logic (capability detection, permissions) |
| `assets/css/p2p-session.css` | Lobby layout styles |
| `assets/css/p2p-lobby.css` | Lobby component styles |

### Tests

| File | Purpose |
|------|---------|
| `test/retro_hex_chat/commands/handlers/p2p_test.exs` | /p2p handler tests |
| `test/retro_hex_chat/commands/handlers/call_test.exs` | /call handler tests |
| `test/retro_hex_chat/commands/handlers/send_file_test.exs` | /sendfile handler tests |
| `test/retro_hex_chat/p2p/session_server_lobby_test.exs` | Lobby extensions tests |
| `test/retro_hex_chat_web/live/p2p_session_live_test.exs` | LiveView tests |
| `assets/test/lib/p2p.test.js` | JS lib tests |
| `assets/test/hooks/p2p_capability_hook.test.js` | JS hook tests |
| `assets/test/hooks/p2p_session_hook.test.js` | JS hook tests |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/retro_hex_chat/commands/registry.ex` | Add "p2p", "call", "sendfile" entries |
| `lib/retro_hex_chat/p2p/session_server.ex` | Add lobby messages + action request state/API |
| `lib/retro_hex_chat/p2p/service.ex` | Add lobby message + action request functions |
| `lib/retro_hex_chat/p2p/p2p.ex` | Expose new lobby/action functions |
| `lib/retro_hex_chat/chat/private_message.ex` | Add "p2p_invite" to allowed types |
| `lib/retro_hex_chat_web/router.ex` | Add `/p2p/:token` route |
| `lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` | Handle :p2p_invite result |
| `assets/js/app.js` | Register P2P hooks |
| `assets/css/app.css` | Import p2p-session.css, p2p-lobby.css |
| `assets/js/lib/notification_toast.js` | Add P2P invite toast with action buttons |

## Validation

```bash
# Run all CI checks
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
mix test --include e2e
mix dialyzer
```

## Key Architecture Decisions

1. **Ephemeral lobby chat** — messages live in SessionServer GenServer state, capped at 100
2. **PM-based invitation** — uses existing `Chat.Service.send_private_message/5` with type "p2p_invite"
3. **Toast notification** — extends `NotificationDispatcherHook` with P2P invite toast type
4. **Bilateral consent** — action requests stored in SessionServer, 60s timeout
5. **Post-consent state** — transitions to "connecting" with placeholder UI (WebRTC handoff)
6. **Hook = wiring, lib = logic** — capability detection logic in `js/lib/p2p.js`
