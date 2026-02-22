# Implementation Plan: Status Bar & Loading States

**Branch**: `031-statusbar-loading-states` | **Date**: 2026-02-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/031-statusbar-loading-states/spec.md`

## Summary

Enhance the existing status bar component with real-time latency measurement (ping/pong), detailed connection state indicators (4 states), and a local clock. Add non-blocking connection banners for brief disconnections (complementing the existing full-overlay for extended ones). Add loading indicators for initial connection, channel history, and channel list fetching. All state is ephemeral (socket assigns + client-side) — no new database migrations.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Storage**: No new PostgreSQL migrations — all state is ephemeral (socket assigns, client-side timers)
**Testing**: ExUnit (unit/integration/liveview/e2e), Vitest + jsdom (JS hooks + lib)
**Target Platform**: Web (modern browsers)
**Project Type**: Phoenix umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Lag measurement ≤ 30s intervals, status bar updates with zero layout shifts, banner debounce ≥ 1s
**Constraints**: No excessive network traffic from ping/pong, banners must not block UI, must coexist with existing reconnect overlay
**Scale/Scope**: Single-user session scope — all state per-socket, no shared server-side state additions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All server logic in Elixir/Phoenix. JS hooks follow existing patterns (wiring only). No JS UI frameworks. |
| II. Umbrella Bounded Contexts | Yes | PASS | Status bar is web-layer only (component + LiveView assigns). No domain context changes needed. |
| III. OTP Process Architecture | No | N/A | No new GenServers or supervision tree changes. Lag ping/pong uses existing LiveView channel. |
| IV. TDD (NON-NEGOTIABLE) | Yes | PASS | Tests written first: ExUnit for LiveView component tests, Vitest for JS hook/lib logic (ping timing, banner debounce, clock formatting). |
| V. Contracts & Behaviours | Marginal | PASS | No new "/" commands. No new behaviours needed — this is component + hook work. |
| VI. Static Analysis | Yes | PASS | All new public functions get @spec. ESLint + Prettier for JS. Credo + Dialyzer for Elixir. |
| VII. Lean LiveViews & Components | Yes | PASS | Status bar remains a function component. LiveView only manages assigns (connection_state, lag_ms, loading states). JS hooks handle timers/DOM. |
| VIII. retro Design Fidelity | Yes | PASS | Uses retro design system status-bar, progress bar. Banners styled with retro window borders. |
| IX. Hot/Cold Data Separation | Yes | PASS | All new state is hot (socket assigns, client timers). No database changes. |
| X. Scalable Architecture | No | N/A | Per-socket state only. No shared state implications. |
| XI. User-Facing Documentation | Yes | PASS | Help topics needed for status bar features (lag indicator, connection states, clock). |

**Gate Result**: PASS — No violations.

## Project Structure

### Documentation (this feature)

```text
specs/031-statusbar-loading-states/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── status_bar.ex          # MODIFY — add lag, clock, connection state sections
│   │   ├── connection_banner.ex   # NEW — disconnection/reconnection banner component
│   │   ├── loading_spinner.ex     # NEW — reusable centered spinner component
│   │   └── connection_progress.ex # NEW — step-by-step connection progress component
│   └── live/
│       ├── chat_live.ex           # MODIFY — add connection_state, lag_ms, loading assigns
│       ├── chat_live.html.heex    # MODIFY — add banner + loading components to template
│       ├── chat_live/
│       │   └── helpers/
│       │       └── connection.ex  # NEW — ping/pong handler, connection state management
│       └── channel_list_live.ex   # MODIFY — add loading progress state
├── assets/
│   ├── js/
│   │   ├── hooks/
│   │   │   ├── lag_hook.js        # NEW — ping/pong timing, push lag events to server
│   │   │   ├── clock_hook.js      # NEW — local time updates every minute
│   │   │   └── connection_banner_hook.js  # NEW — debounce, countdown, fade-out
│   │   └── lib/
│   │       ├── lag.js             # NEW — ping/pong logic (testable)
│   │       ├── clock.js           # NEW — time formatting (testable)
│   │       └── connection_banner.js # NEW — banner state machine (testable)
│   ├── css/
│   │   ├── connection-banner.css  # NEW — banner styles (red/green, fade animation)
│   │   ├── loading-spinner.css    # NEW — centered spinner styles
│   │   └── connection-progress.css # NEW — step indicator styles
│   └── test/
│       ├── hooks/
│       │   ├── lag_hook.test.js   # NEW
│       │   ├── clock_hook.test.js # NEW
│       │   └── connection_banner_hook.test.js # NEW
│       └── lib/
│           ├── lag.test.js        # NEW
│           ├── clock.test.js      # NEW
│           └── connection_banner.test.js # NEW
└── test/
    └── retro_hex_chat_web/
        ├── components/
        │   ├── status_bar_test.exs      # MODIFY — test new fields
        │   ├── connection_banner_test.exs # NEW
        │   ├── loading_spinner_test.exs  # NEW
        │   └── connection_progress_test.exs # NEW
        └── live/
            └── chat_live_test.exs        # MODIFY — test connection state transitions

apps/retro_hex_chat/
├── lib/retro_hex_chat/chat/
│   └── help_topics.ex             # MODIFY — add status bar, lag, clock help topics
└── test/retro_hex_chat/chat/
    └── help_topics_test.exs       # MODIFY — test new help topics
```

**Structure Decision**: Follows the existing umbrella structure. All new code lives in the web layer (`retro_hex_chat_web`) since this feature is purely presentational — no domain logic changes. JS follows the "hook = wiring, lib = logic" pattern per Constitution IV. New CSS files follow the project's component-per-file convention (40+ lines threshold).

## Complexity Tracking

> No violations to justify — all constitution gates pass.
