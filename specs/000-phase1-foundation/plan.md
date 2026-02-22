# Implementation Plan: RetroHexChat Phase 1 — Foundation & Core Chat

**Branch**: `001-phase1-foundation` | **Date**: 2026-02-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-phase1-foundation/spec.md`

## Summary

Build the complete Phase 1 of RetroHexChat: a web-based IRC client with
mIRC-style interface and retro dark theme. The system is an Elixir
Phoenix LiveView umbrella application with real-time chat, channels
managed by OTP GenServers, private messaging, a full "/" command system
(18 commands), NickServ/ChanServ services, channel modes, chat search,
and a faithful retro-styled dark theme UI. All real-time communication
flows through Phoenix PubSub, user presence through Phoenix Presence,
and messages are persisted in PostgreSQL with cursor-based pagination.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x,
  Phoenix PubSub, Phoenix Presence, retro CSS framework, bcrypt_elixir, esbuild
**Storage**: PostgreSQL 16+ via Ecto (cursor-based pagination, GIN/trigram
  indexes for search)
**Testing**: ExUnit (async sandbox), Mox, ExMachina, StreamData, Floki
**Static Analysis**: Credo, Dialyxir, mix format
**Target Platform**: Web browser (any modern browser), server on Linux/macOS
**Project Type**: Web application (Phoenix umbrella)
**Performance Goals**: <200ms message delivery end-to-end, <100ms for
  50-message page loads on channels with 100k messages, <60s full test
  suite, <10s unit-only tests
**Constraints**: 50 concurrent users across 10 channels without degradation,
  5 msg/sec per-user rate limit, 2 cmd/sec per-user command rate limit,
  1000-char max user message length
**Scale/Scope**: 12 user stories, 76 functional requirements, 18 slash
  commands, 7 bounded contexts, ~8 DB tables, 3 LiveViews, ~15 function
  components, 4 JS hooks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Elixir & Phoenix Exclusive Stack | PASS | Elixir 1.17+, Phoenix 1.7+, LiveView 1.0+, PostgreSQL 16+, retro design system. Zero JS UI frameworks. |
| II. Umbrella App with Bounded Contexts | PASS | `apps/retro_hex_chat` (domain) + `apps/retro_hex_chat_web` (web). 7 bounded contexts: Accounts, Chat, Channels, Services, Presence, Commands, RateLimit. Layers per context declared below (N/A where inapplicable). |
| III. OTP Process Architecture | PASS | DynamicSupervisor for channels, GenServer per channel, Registry via `via_tuple`, GenServers for NickServ and ChanServ. Supervision tree from day zero. |
| IV. Test-First Development | PASS | ExUnit async, Mox (behaviour-based), ExMachina factories, StreamData for parsers, Floki for HTML. Tags: @tag :unit, :integration, :liveview. Time budgets: <60s full, <10s unit. |
| V. Contracts and Behaviours | PASS | `Handler` behaviour for each "/" command (execute/2, validate/1, help/0). 18 separate command modules. Protocols for message formatting. |
| VI. Static Analysis from Day One | PASS | Credo, Dialyxir, mix format configured from first commit. @spec on all public functions. |
| VII. Lean LiveViews & Component Architecture | PASS | 3 thin LiveViews delegating to contexts. ~15 function components. 4 minimal JS hooks (scroll, sound, keyboard, command palette). PubSub topics: "channel:#{name}", "user:#{nickname}", "service:nickserv/chanserv". LiveView streams for messages. |
| VIII. retro Design Fidelity | PASS | retro design system as base, dark theme via CSS custom properties, 3D borders, monospace fonts, 16x16 icons, semantic HTML. |
| IX. Hot/Cold Data Separation | PASS | GenServer/ETS for active channels, presence, rate limits (hot). PostgreSQL for messages, registered nicks, registered channels, access lists (cold). Environment-aware config. |
| X. Scalable Architecture | PASS | Process-per-channel via DynamicSupervisor, Phoenix PubSub (pg adapter for future clustering), schemas designed for partitioning. |

**Gate Result**: ALL PASS. No violations. Complexity Tracking section not needed.

### Bounded Context Layering (Constitution II)

Each context implements the layers that apply to its domain. Layers
marked N/A are structurally inapplicable (e.g., no Schema for purely
in-memory contexts, no Queries for contexts without DB access).

| Context | Schema | Queries | Service/UseCase | Policy | Events |
|---------|--------|---------|-----------------|--------|--------|
| **Accounts** | N/A (sessions are in-memory) | N/A | `session.ex` (session lifecycle) | `nickname_validator.ex` (nick rules), `policy.ex` (identity checks) | `events.ex` (connected, disconnected, nick_changed) |
| **Chat** | `message.ex`, `private_message.ex` | `queries.ex` (cursor pagination), `search.ex` | `service.ex` (send message, persist, broadcast) | `policy.ex` (rate limit check, content validation, moderated channel check) | `events.ex` (message_sent, message_persisted) |
| **Channels** | `channel.ex` (registered channels DB) | `queries.ex` (registered channel lookups) | `server.ex` (GenServer), `supervisor.ex`, `registry.ex` | `policy.ex` (join permissions, mode enforcement, op checks) | `events.ex` (channel_created, channel_destroyed, mode_changed, topic_changed) |
| **Services** | `registered_nick.ex`, `registered_channel.ex`, `access_list_entry.ex`, `ban.ex` | `queries.ex` (nick lookups, access list lookups, ban lookups) | `nick_serv.ex` (GenServer), `chan_serv.ex` (GenServer) | `policy.ex` (identify required, founder-only, hierarchical access) | `events.ex` (nick_registered, nick_identified, channel_registered, privilege_granted) |
| **Presence** | N/A (ephemeral, Phoenix Presence) | N/A | `tracker.ex` (presence tracking, away status) | N/A (presence is read-only, no authorization) | `events.ex` (user_online, user_offline, user_away) |
| **Commands** | N/A (commands are ephemeral) | N/A | `parser.ex`, `dispatcher.ex`, `registry.ex` | `policy.ex` (permission checks before dispatch: is operator? is identified?) | `events.ex` (command_executed — Telemetry) |
| **RateLimit** | N/A (ETS, no DB) | N/A | `limiter.ex` (ETS token bucket) | N/A (rate limit IS the policy, enforced by limiter) | `events.ex` (rate_limited — Telemetry) |

**Notes**:
- Events modules emit `:telemetry` events for observability (Constitution VIII).
- Policy modules centralize authorization logic extracted from handlers/GenServers.
- Contexts that are purely in-memory (Accounts sessions, Presence, RateLimit)
  have Schema/Queries as N/A — they never touch PostgreSQL.

## Project Structure

### Documentation (this feature)

```text
specs/001-phase1-foundation/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology decisions
├── data-model.md        # Phase 1 output — entity model
├── quickstart.md        # Phase 1 output — dev setup guide
├── contracts/           # Phase 1 output — internal API contracts
│   ├── commands.md      # Command handler + dispatch flow contracts
│   └── services.md      # NickServ timer + ChanServ auto-privilege contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/
├── retro_hex_chat/                    # Domain app (pure Elixir)
│   ├── lib/retro_hex_chat/
│   │   ├── accounts/                  # Bounded context: identity
│   │   │   ├── session.ex             # Session struct (in-memory)
│   │   │   ├── nickname_validator.ex  # Validation rules
│   │   │   ├── policy.ex              # Identity checks (nick ownership)
│   │   │   └── events.ex             # Telemetry: connected, disconnected, nick_changed
│   │   ├── channels/                  # Bounded context: channels
│   │   │   ├── channel.ex             # Schema (registered channels)
│   │   │   ├── server.ex              # GenServer per channel
│   │   │   ├── supervisor.ex          # DynamicSupervisor
│   │   │   ├── registry.ex            # Channel registry helpers
│   │   │   ├── queries.ex             # Registered channel DB lookups
│   │   │   ├── modes.ex               # Mode parsing/enforcement
│   │   │   ├── membership.ex          # In-memory membership struct
│   │   │   ├── policy.ex              # Join permissions, mode enforcement, op checks
│   │   │   └── events.ex             # Telemetry: channel_created, destroyed, mode_changed
│   │   ├── chat/                      # Bounded context: messages
│   │   │   ├── message.ex             # Schema
│   │   │   ├── private_message.ex     # Schema
│   │   │   ├── queries.ex             # Cursor-based pagination
│   │   │   ├── search.ex              # Text search (trigram)
│   │   │   ├── service.ex             # Send/persist/broadcast orchestration
│   │   │   ├── policy.ex              # Content validation, moderated check, rate limit gate
│   │   │   └── events.ex             # Telemetry: message_sent, message_persisted
│   │   ├── commands/                  # Bounded context: "/" commands
│   │   │   ├── handler.ex             # Behaviour definition
│   │   │   ├── parser.ex              # Command parser
│   │   │   ├── dispatcher.ex          # Route to handler + consume results
│   │   │   ├── registry.ex            # Command registry
│   │   │   ├── policy.ex              # Pre-dispatch permission checks
│   │   │   ├── events.ex             # Telemetry: command_executed
│   │   │   └── handlers/              # One module per command
│   │   │       ├── join.ex
│   │   │       ├── part.ex
│   │   │       ├── msg.ex
│   │   │       ├── query.ex
│   │   │       ├── me.ex
│   │   │       ├── nick.ex
│   │   │       ├── topic.ex
│   │   │       ├── kick.ex
│   │   │       ├── ban.ex
│   │   │       ├── mode.ex
│   │   │       ├── whois.ex
│   │   │       ├── list.ex
│   │   │       ├── clear.ex
│   │   │       ├── away.ex
│   │   │       ├── quit.ex
│   │   │       ├── help.ex
│   │   │       ├── ns.ex
│   │   │       └── cs.ex
│   │   ├── presence/                  # Bounded context: presence
│   │   │   ├── tracker.ex             # Presence tracking + away status
│   │   │   └── events.ex             # Telemetry: user_online, user_offline, user_away
│   │   ├── rate_limit/                # Bounded context: flood control
│   │   │   ├── limiter.ex             # ETS-based token bucket
│   │   │   └── events.ex             # Telemetry: rate_limited
│   │   └── services/                  # Bounded context: NickServ + ChanServ
│   │       ├── nick_serv.ex           # GenServer (includes 60s identify timer)
│   │       ├── chan_serv.ex           # GenServer (includes auto-privilege on join)
│   │       ├── registered_nick.ex     # Schema
│   │       ├── registered_channel.ex  # Schema
│   │       ├── access_list_entry.ex   # Schema
│   │       ├── ban.ex                 # Schema (persisted bans for registered channels)
│   │       ├── queries.ex             # Nick/channel/access list DB lookups
│   │       ├── policy.ex              # Identify required, founder-only, hierarchical access
│   │       └── events.ex             # Telemetry: nick_registered, channel_registered, etc.
│   ├── priv/repo/migrations/          # Ecto migrations
│   └── test/
│       ├── retro_hex_chat/
│       │   ├── accounts/              # Unit tests per context
│       │   ├── channels/
│       │   ├── chat/
│       │   ├── commands/
│       │   ├── presence/
│       │   ├── rate_limit/
│       │   └── services/
│       └── support/
│           ├── factory.ex             # ExMachina factory
│           └── mocks.ex               # Mox definitions
│
└── retro_hex_chat_web/                # Web app
    ├── lib/retro_hex_chat_web/
    │   ├── endpoint.ex
    │   ├── router.ex
    │   ├── telemetry.ex               # Telemetry event handlers (logging)
    │   ├── live/
    │   │   ├── connect_live.ex        # Connection dialog
    │   │   ├── chat_live.ex           # Main MDI layout
    │   │   └── channel_list_live.ex   # Channel list modal
    │   ├── components/
    │   │   ├── layouts.ex             # Root/app layouts
    │   │   ├── window.ex              # retro design system Window wrapper
    │   │   ├── title_bar.ex
    │   │   ├── status_bar.ex
    │   │   ├── menu_bar.ex
    │   │   ├── toolbar.ex
    │   │   ├── treebar.ex
    │   │   ├── nicklist.ex
    │   │   ├── chat_message.ex
    │   │   ├── command_palette.ex
    │   │   ├── search_bar.ex
    │   │   ├── context_menu.ex
    │   │   ├── dialog.ex
    │   │   └── scroll_loader.ex
    │   └── channels/
    │       └── user_socket.ex         # (if needed for LiveView)
    ├── assets/
    │   ├── css/
    │   │   ├── app.css                # Main CSS entry
    │   │   └── dark-theme.css         # retro design system dark theme overrides
    │   ├── js/
    │   │   ├── app.js                 # Main JS entry
    │   │   └── hooks/
    │   │       ├── scroll_hook.js
    │   │       ├── sound_hook.js
    │   │       ├── keyboard_hook.js
    │   │       └── command_palette_hook.js
    │   ├── static/
    │   │   ├── sounds/                # .wav notification sounds
    │   │   └── icons/                 # 16x16 pixel art icons
    │   └── vendor/                    # (retro design system copied here by esbuild)
    └── test/
        ├── retro_hex_chat_web/
        │   ├── live/                  # LiveView tests
        │   └── components/            # Component tests
        └── support/
```

**Structure Decision**: Phoenix umbrella app with two applications.
Domain logic in `apps/retro_hex_chat`, web layer in
`apps/retro_hex_chat_web`. This is the standard Phoenix umbrella pattern
per Constitution Principle II.

## Complexity Tracking

> No violations detected. All constitutional principles are satisfied.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
