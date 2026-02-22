# Implementation Plan: Visual Feedback & Unread Indicators

**Branch**: `030-visual-feedback-unread` | **Date**: 2026-02-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/030-visual-feedback-unread/spec.md`

## Summary

Add comprehensive visual feedback to RetroHexChat: treebar unread indicators with numeric badges, red dot for mentions, 6 visual states (normal, unread, highlight, active, muted, disconnected); kick notification dialog with queuing; copy/settings confirmation toasts via existing Z2 toast infrastructure; optimistic message send with pending/failed/retry states; and channel join flash.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Primary Dependencies**: Phoenix LiveView (streams, push_event), retro design system, existing toast component (Z2)
**Storage**: No new PostgreSQL migrations — all state is ephemeral (socket assigns, client-side)
**Testing**: ExUnit (E2E via LiveViewTest), Vitest + jsdom (JS hooks/libs)
**Target Platform**: Web browser (desktop-optimized, retro aesthetic)
**Project Type**: Phoenix umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Optimistic messages appear < 100ms; treebar updates < 50ms; 20+ channels tracked simultaneously
**Constraints**: No database changes; toast reuse from Z2; retro design system design fidelity
**Scale/Scope**: 26 functional requirements, 5 user stories, ~15 files modified/created

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Relevant? | Status | Notes |
|---|-----------|-----------|--------|-------|
| I | Elixir & Phoenix Exclusive Stack | Yes | PASS | All server logic in Elixir/Phoenix. JS hooks follow existing patterns. |
| II | Umbrella App with Bounded Contexts | Yes | PASS | Domain logic stays in retro_hex_chat (UnreadTracker). Web layer in retro_hex_chat_web. |
| III | OTP Process Architecture | No | N/A | No new GenServers. Uses existing channel GenServer for message send. |
| IV | Test-First Development | Yes | PASS | JS lib tests + hook tests + E2E LiveView tests. Hook=wiring, lib=logic. |
| V | Contracts and Behaviours | No | N/A | No new behaviours needed. |
| VI | Static Analysis from Day One | Yes | PASS | All 9 CI checks enforced. |
| VII | Lean LiveViews & Component Architecture | Yes | PASS | LiveView delegates to domain. Components for treebar badges and kick dialog. |
| VIII | retro Design Fidelity | Yes | PASS | retro dialogs, badges styled to match aesthetic. |
| IX | Hot/Cold Data Separation | Yes | PASS | All new state is hot (socket assigns, client-side). No DB changes. |
| X | Scalable Architecture | No | N/A | Unread tracking is per-socket — scales with LiveView processes. |
| XI | User-Facing Documentation | Yes | PASS | Help topics for unread indicators, kick dialog, copy feedback. |

## Project Structure

### Documentation (this feature)

```text
specs/030-visual-feedback-unread/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── liveview-events.md
│   └── js-api.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   └── chat/
│       └── unread_tracker.ex              # NEW — pure unread count logic (domain)

apps/retro_hex_chat_web/
├── assets/
│   ├── css/
│   │   ├── treebar.css                    # NEW — treebar badge + state CSS
│   │   └── app.css                        # MODIFIED — add treebar.css import
│   ├── js/
│   │   ├── lib/
│   │   │   ├── unread.js                  # NEW — unread badge rendering logic
│   │   │   └── feedback_toast.js          # NEW — copy/settings toast trigger logic
│   │   └── hooks/
│   │       ├── treebar_hook.js            # MODIFIED — add badge rendering, join flash
│   │       └── scroll_hook.js             # MODIFIED — add copy toast trigger
│   └── test/
│       ├── lib/
│       │   ├── unread.test.js             # NEW — unread lib tests
│       │   └── feedback_toast.test.js     # NEW — feedback toast lib tests
│       └── hooks/
│           └── treebar_hook.test.js       # MODIFIED — add badge/flash tests
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── treebar.ex                     # MODIFIED — add badge rendering, muted/disconnected states
│   │   └── kick_dialog.ex                 # NEW — kick notification dialog component
│   └── live/chat_live/
│       ├── helpers/
│       │   └── channel.ex                 # MODIFIED — add join flash push_event
│       ├── pubsub_handlers/
│       │   ├── messages.ex                # MODIFIED — increment unread counts
│       │   └── channel_state.ex           # MODIFIED — kick dialog trigger
│       ├── core_events.ex                 # MODIFIED — optimistic send, retry
│       ├── options_events.ex              # MODIFIED — settings saved toast
│       └── kick_events.ex                 # NEW — kick dialog event handlers
└── test/
    └── retro_hex_chat_web/live/
        ├── chat_live/
        │   └── kick_dialog_test.exs       # NEW — kick dialog E2E tests
        └── visual_feedback_test.exs       # NEW — unread indicator E2E tests
```

**Structure Decision**: Follows existing umbrella pattern. Domain logic (UnreadTracker) in retro_hex_chat. All UI, hooks, and components in retro_hex_chat_web. JS follows hook=wiring/lib=logic (Constitution IV).

## Complexity Tracking

> No constitution violations. No entries needed.
