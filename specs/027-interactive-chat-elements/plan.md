# Implementation Plan: Interactive Chat Elements

**Branch**: `027-interactive-chat-elements` | **Date**: 2026-02-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/027-interactive-chat-elements/spec.md`

## Summary

Make chat messages interactive by adding hover tooltips and click actions to three element types already detected in the DOM: URLs (hover shows page title, click opens tab), channel names (hover shows user count, click joins/switches), and nicks (hover card with whois data after 500ms, single-click inserts nick, double-click opens PM). The existing data-attribute system (`data-url`, `data-channel`, `data-nick`) and context menu detection logic provide the foundation — this feature adds the left-click and hover layer on top.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild
**Storage**: PostgreSQL 16+ (link preview cache via ETS, channel state via GenServer — no new migrations)
**Testing**: ExUnit (Elixir), Vitest + jsdom (JavaScript)
**Target Platform**: Web browser (desktop-first, Windows 98 aesthetic)
**Project Type**: Umbrella web application (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Hover feedback within 100ms, nick hover card within 600ms (500ms delay + 100ms render)
**Constraints**: Must not interfere with text selection; must coexist with context menu system; no new database migrations
**Scale/Scope**: 3 interactive element types, ~6 new/modified files, 1 new CSS file, 1 new JS lib module, 1 new LiveView component, 1 new event handler module

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Compliance |
|-----------|-----------|------------|
| I. Elixir & Phoenix Exclusive | Yes | LiveView events for server-side actions, JS hooks for client-side hover/click only. No JS UI frameworks. |
| II. Umbrella Bounded Contexts | Yes | No new domain logic needed — reuses existing Chat, Channels, Presence contexts. New code lives in web layer (components, hooks, helpers). |
| III. OTP Process Architecture | Yes | Channel user count fetched from existing GenServer (`Server.get_state/1`). No new processes. |
| IV. TDD | Yes | Unit tests for JS lib functions (hover debounce, click-vs-drag detection). LiveView tests for event handlers. |
| V. Contracts & Behaviours | Marginal | No new behaviours needed — feature extends existing rendering and event handling. |
| VI. Static Analysis | Yes | All new Elixir functions get `@spec`. ESLint + Prettier for JS. Credo + Dialyzer pass. |
| VII. Lean LiveViews | Yes | LiveView delegates to existing helpers (Whois, Channel, PM). New component for hover card rendering only. |
| VIII. Windows 98 Design Fidelity | Yes | Hover card uses 98.css window styling (3D beveled borders). Tooltip uses system font. |
| IX. Hot/Cold Data Separation | Yes | All data for hover cards comes from in-memory sources (GenServer state, Tracker presence, ETS cache). No DB queries on hover. |
| X. Scalable Architecture | N/A | No new architectural patterns introduced. |
| XI. User-Facing Documentation | Yes | Help topic for interactive elements must be added to HelpTopics. |

**Gate Result**: PASS — all relevant principles satisfied with no violations.

## Project Structure

### Documentation (this feature)

```text
specs/027-interactive-chat-elements/
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
│   │   └── hover_card.ex              # NEW — nick hover card + channel/URL tooltip components
│   └── live/chat_live/
│       └── hover_events.ex            # NEW — handle_event for hover card data requests
├── assets/
│   ├── js/
│   │   ├── lib/
│   │   │   └── interactive.js         # NEW — hover debounce, click-vs-drag, tooltip positioning
│   │   └── hooks/
│   │       └── scroll_hook.js         # MODIFIED — add hover/click listeners for interactive elements
│   ├── css/
│   │   ├── hover-card.css             # NEW — nick hover card + tooltip styles (98.css aesthetic)
│   │   └── app.css                    # MODIFIED — add hover-card.css import
│   └── test/
│       └── lib/
│           └── interactive.test.js    # NEW — tests for interactive.js lib functions
└── test/
    └── retro_hex_chat_web/
        └── live/chat_live/
            └── hover_events_test.exs  # NEW — tests for hover event handlers

apps/retro_hex_chat/
├── lib/retro_hex_chat/chat/
│   └── formatter.ex                   # MODIFIED — channel linkification already handles punctuation trimming
│   └── url_detector.ex                # UNCHANGED — existing URL detection sufficient
└── test/
    └── retro_hex_chat/chat/
        └── formatter_test.exs         # MODIFIED — add tests for punctuation edge cases if needed
```

**Structure Decision**: Follows existing umbrella pattern. All new code lives in the web layer since the domain contexts already provide the data sources. One new component (`hover_card.ex`), one new event handler module (`hover_events.ex`), one new JS lib module (`interactive.js`), and one new CSS file (`hover-card.css`).

## Complexity Tracking

> No violations — table not needed.
