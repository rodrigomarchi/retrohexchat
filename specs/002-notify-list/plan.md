# Implementation Plan: Notify List (Buddy List)

**Branch**: `002-notify-list` | **Date**: 2026-02-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-notify-list/spec.md`

## Summary

Implement a persistent buddy list (Notify List) that tracks friends' online/offline presence and delivers real-time notifications. The feature spans all layers: a new `notify_list_entries` database table for persistence, a new `RetroHexChat.Presence.NotifyList` context module for in-memory list management with debounced presence detection, a Status window for system-level notifications, a Notify List window for buddy management, `/notify` slash commands, and auto-whois integration.

Key technical approach: introduce a global presence topic (`"presence:global"`) so that all user connect/disconnect events are visible system-wide (current presence is per-channel only). Each LiveView process subscribes to this topic and filters events against its local notify list. Debouncing is handled per-LiveView with Process timers. Persistence is via Ecto for identified users; guests use in-memory Session state only.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (new `notify_list_entries` table) + in-memory Session state for guests
**Testing**: ExUnit, Mox, ExMachina, StreamData, Floki (full pyramid: unit, integration, liveview, e2e)
**Target Platform**: Web (Linux/macOS server, browser client)
**Project Type**: Phoenix umbrella (existing)
**Performance Goals**: Notification delivery <5s after buddy connects; all CRUD operations <2s
**Constraints**: Max 50 entries per user; debounce window 10s for rapid connect/disconnect
**Scale/Scope**: 50 buddies/user, existing user base, 2 new windows (Status + Notify List)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All implementation in Elixir/Phoenix/LiveView. No JS frameworks. |
| II. Umbrella with Bounded Contexts | Yes | PASS | New modules in `Presence` context (NotifyList). New command handlers in `Commands`. Web components in `retro_hex_chat_web`. |
| III. OTP Process Architecture | Yes | PASS | No new GenServers needed — notify list state lives in LiveView assigns + DB. Global presence uses existing PubSub. Debounce uses Process timers within LiveView. |
| IV. Test-First Development | Yes | PASS | TDD for all layers. Unit tests for context module, integration for DB persistence, LiveView tests for UI, e2e for full flows. |
| V. Contracts and Behaviours | Yes | PASS | `/notify` command implements existing `Handler` behaviour. NotifyList context exposes @spec'd public API. |
| VI. Static Analysis from Day One | Yes | PASS | All new modules will have @spec, pass Credo strict, Dialyxir, mix format. |
| VII. Lean LiveViews & Components | Yes | PASS | ChatLive delegates to `Presence.NotifyList` context. New function components for Status window and Notify List window. PubSub topic `"presence:global"` follows naming convention. |
| VIII. retro Design Fidelity | Yes | PASS | Both windows use retro design system. Status window and Notify List window match MDI layout. |
| IX. Hot/Cold Data Separation | Yes | PASS | Hot: in-memory notify list in Session assigns + PubSub events. Cold: `notify_list_entries` table in PostgreSQL for registered users. |
| X. Scalable Architecture | Yes | PASS | Global presence topic scales via Phoenix PubSub (pg adapter). No process-per-user — events are broadcast, filtered locally. |

**Gate result: ALL PASS. No violations.**

## Project Structure

### Documentation (this feature)

```text
specs/002-notify-list/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research findings
├── data-model.md        # Phase 1: data model design
├── quickstart.md        # Phase 1: developer quickstart
├── contracts/           # Phase 1: API contracts
│   └── notify-list-context.md
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/
│   ├── presence/
│   │   └── notify_list.ex                    # NEW: NotifyList context module
│   ├── accounts/
│   │   └── session.ex                        # MODIFIED: add notify_list fields
│   ├── commands/
│   │   ├── handlers/
│   │   │   └── notify.ex                     # NEW: /notify command handler
│   │   └── registry.ex                       # MODIFIED: register /notify
│   └── services/
│       └── nick_serv.ex                      # MODIFIED: broadcast on identify
├── priv/repo/migrations/
│   └── XXXXXXXXXX_create_notify_list_entries.exs  # NEW: migration
└── test/
    ├── retro_hex_chat/
    │   ├── presence/
    │   │   └── notify_list_test.exs          # NEW: context unit + integration tests
    │   └── commands/handlers/
    │       └── notify_test.exs               # NEW: command handler tests
    └── ...

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── chat_live.ex                      # MODIFIED: notify list + status window integration
│   └── components/
│       ├── status_window.ex                  # NEW: Status window component
│       └── notify_list_window.ex             # NEW: Notify List window component
├── assets/
│   └── js/
│       └── hooks/
│           └── notify_list_hook.js           # NEW: double-click, scroll behavior
└── test/
    └── retro_hex_chat_web/
        └── live/
            ├── chat_live_notify_test.exs     # NEW: LiveView tests for notify features
            └── chat_live_status_test.exs     # NEW: LiveView tests for status window
```

**Structure Decision**: Follows existing umbrella structure. New `NotifyList` module lives in the `Presence` bounded context since it fundamentally extends presence tracking. No new OTP processes — state management through LiveView assigns and database. New function components follow the existing pattern (treebar.ex, dialog.ex).
