# Implementation Plan: Contextual Tips & Progressive Disclosure

**Branch**: `029-contextual-tips` | **Date**: 2026-02-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/029-contextual-tips/spec.md`

## Summary

Implement a contextual tip system that shows retro-styled toast notifications at specific user milestones (first message, first join, first PM, first highlight, idle). Tips fire once per user, queue when simultaneous, respect dialog/modal state, and persist seen state in localStorage. The toast component is reusable by other features. A global "Não mostrar mais dicas" toggle is available both on the toast and in Settings.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend)
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Storage**: localStorage (tip seen state + global suppression) — no PostgreSQL changes
**Testing**: ExUnit (Elixir), Vitest + jsdom (JavaScript)
**Target Platform**: Web browser (desktop-first, retro aesthetic)
**Project Type**: Phoenix umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Tips display within 500ms of trigger; no UI jank
**Constraints**: Toast must not steal input focus; max 1 toast visible at a time
**Scale/Scope**: 5 tip types, 1 reusable toast component, 1 Settings toggle

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive Stack | Yes | PASS | LiveView for server events, JS hooks for localStorage/idle timer only |
| II. Umbrella with Bounded Contexts | Yes | PASS | No domain logic changes — tips are purely a web-layer concern (presentation + localStorage) |
| III. OTP Process Architecture | No | N/A | No new GenServers needed — tips are client-side state |
| IV. Test-First Development | Yes | PASS | Vitest for JS lib (tip state, queue logic), ExUnit for LiveView event handlers |
| V. Contracts and Behaviours | No | N/A | No new commands or polymorphic dispatch |
| VI. Static Analysis from Day One | Yes | PASS | ESLint/Prettier for JS, Credo/Dialyzer for Elixir, @spec on all public functions |
| VII. Lean LiveViews & Components | Yes | PASS | Toast is a function component; LiveView only pushes events to JS hook |
| VIII. retro Design Fidelity | Yes | PASS | Toast styled with retro window class, 3D beveled borders, dark theme |
| IX. Hot/Cold Data Separation | Yes | PASS | Tip state in localStorage (hot, client-side) — no database needed |
| X. Scalable Architecture | No | N/A | Client-only feature — no server-side scaling concern |
| XI. User-Facing Documentation | Yes | PASS | Help topic for "Contextual Tips" in Features category |

**Pre-design gate**: PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/029-contextual-tips/
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
├── assets/
│   ├── css/
│   │   └── toast.css                          # NEW — Toast component styles (Layer 4: Components)
│   ├── js/
│   │   ├── hooks/
│   │   │   └── contextual_tips_hook.js        # NEW — Wiring: pushEvent ↔ DOM, idle timer
│   │   └── lib/
│   │       ├── tips.js                        # NEW — Pure logic: tip state, queue, localStorage
│   │       └── toast.js                       # NEW — Pure logic: toast DOM creation/animation
│   └── test/
│       ├── hooks/
│       │   └── contextual_tips_hook.test.js   # NEW — Hook behavioral tests
│       └── lib/
│           ├── tips.test.js                   # NEW — Tip state/queue unit tests
│           └── toast.test.js                  # NEW — Toast DOM unit tests
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── toast.ex                           # NEW — Phoenix function component
│   └── live/chat_live/
│       └── tip_events.ex                      # NEW — LiveView event handlers for tips

apps/retro_hex_chat/
└── lib/retro_hex_chat/chat/
    └── help_topics.ex                         # MODIFIED — Add "Contextual Tips" topic
```

**Structure Decision**: Follows existing umbrella patterns. Tips are a web-layer feature (no domain logic). JS follows hook=wiring/lib=logic pattern. CSS gets its own file (`toast.css`) since it will exceed 40 lines and has a unique `.toast-*` class prefix.

## Complexity Tracking

> No constitution violations — table not needed.
