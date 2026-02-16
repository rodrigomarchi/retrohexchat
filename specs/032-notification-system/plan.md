# Implementation Plan: Notification System

**Branch**: `032-notification-system` | **Date**: 2026-02-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/032-notification-system/spec.md`

## Summary

Unified notification system that routes chat events (mentions, PMs, channel messages, joins/leaves) through a central dispatcher to six output channels: treebar badges, toast popups, sounds, title flash, browser native notifications, and favicon badge. Includes per-channel notification levels (normal/mentions only/mute), global toggles, notification trigger rules, Do Not Disturb mode, privacy mode, and a notification center panel. Server-side routing logic determines *what* triggers a notification; a client-side dispatcher determines *how* to deliver it based on user preferences, DND state, tab visibility, and browser permissions.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild
**Storage**: PostgreSQL 16+ (existing `user_preferences.message_settings` JSONB — no new migration), localStorage (guest preferences, DND state)
**Testing**: ExUnit (unit, integration, LiveView, e2e), Vitest + jsdom (JS lib + hook tests)
**Target Platform**: Modern browsers (Chrome, Firefox, Safari, Edge)
**Project Type**: Umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Notifications delivered within 1 second of event; max 3 simultaneous toasts
**Constraints**: No new database migrations; notification entries are ephemeral (session-scoped)
**Scale/Scope**: Single-server deployment, ~50 notification center entries per session

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All server logic in Elixir/Phoenix. JS limited to hooks + lib functions. No JS UI frameworks. |
| II. Umbrella with Bounded Contexts | Yes | PASS | Domain logic (`notification_preferences.ex`, `notification_router.ex`) in `retro_hex_chat`. Web layer (components, hooks, event handlers) in `retro_hex_chat_web`. |
| III. OTP Process Architecture | No | N/A | No new GenServers needed — notification state is per-session (socket assigns). |
| IV. Test-First Development | Yes | PASS | TDD for all modules. JS follows hook=wiring/lib=logic pattern. Vitest for JS, ExUnit for Elixir. |
| V. Contracts and Behaviours | Yes | PASS | No new behaviours needed — notification routing is a pure function module, not a polymorphic dispatch. |
| VI. Static Analysis | Yes | PASS | `@spec` on all public functions. ESLint + Prettier for JS. Credo + Dialyzer for Elixir. |
| VII. Lean LiveViews & Components | Yes | PASS | ChatLive delegates to helpers/notifications.ex. Notification routing logic in domain layer. PubSub topics unchanged. |
| VIII. Windows 98 Design Fidelity | Yes | PASS | Notification center styled as 98.css window dropdown. Toasts use existing 98.css window styling. Bell icon is 16x16 pixel art. |
| IX. Hot/Cold Data Separation | Yes | PASS | Notification entries are ephemeral (socket assigns — hot). Preferences persisted in PostgreSQL (cold). No new migrations. |
| X. Scalable Architecture | Yes | PASS | Per-session state in socket assigns scales naturally with Phoenix. No shared mutable state. |
| XI. User-Facing Documentation | Yes | PASS | Help topics for: Notifications, Do Not Disturb, Notification Center, per-channel notification settings. |

**Gate result**: PASS — all relevant principles satisfied, no violations.

## Project Structure

### Documentation (this feature)

```text
specs/032-notification-system/
├── plan.md              # This file
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: entity definitions
├── quickstart.md        # Phase 1: implementation guide
├── contracts/
│   └── liveview-events.md  # Phase 1: push_event/pushEvent contracts
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/chat/
│   ├── notification_preferences.ex    # Domain: CRUD, defaults, validation
│   └── notification_router.ex         # Domain: pure routing logic
└── test/retro_hex_chat/chat/
    ├── notification_preferences_test.exs
    └── notification_router_test.exs

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/chat_live/
│   │   ├── helpers/notifications.ex              # Build + push notification events
│   │   └── event_handlers/notification_events.ex # Handle client notification events
│   └── components/
│       ├── notification_center.ex      # Bell dropdown panel component
│       └── notifications_panel.ex      # Options dialog Notifications tab
├── assets/
│   ├── js/
│   │   ├── lib/
│   │   │   ├── notification_dispatcher.js  # Core: receive event, check prefs, fan out
│   │   │   ├── notification_toast.js       # Toast queue (max 3 visible)
│   │   │   ├── browser_notification.js     # Notification API wrapper
│   │   │   ├── favicon_badge.js            # Canvas overlay on favicon
│   │   │   └── notification_prefs.js       # localStorage for guest prefs
│   │   └── hooks/
│   │       └── notification_dispatcher_hook.js  # LiveView hook wiring
│   ├── test/
│   │   ├── lib/
│   │   │   ├── notification_dispatcher.test.js
│   │   │   ├── notification_toast.test.js
│   │   │   ├── browser_notification.test.js
│   │   │   └── favicon_badge.test.js
│   │   └── hooks/
│   │       └── notification_dispatcher_hook.test.js
│   └── css/
│       └── notification-center.css
└── test/retro_hex_chat_web/live/chat_live/
    └── notification_test.exs
```

**Structure Decision**: Follows existing umbrella structure. Domain logic (pure Elixir, zero Phoenix deps) in `retro_hex_chat`. Web layer (LiveView helpers, components, JS hooks) in `retro_hex_chat_web`. JS follows hook=wiring/lib=logic pattern per Constitution IV.

## Complexity Tracking

No violations to justify — all principles satisfied.
