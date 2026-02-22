# Implementation Plan: Session Persistence — PM Conversations, Auto-Join & Notifications

**Branch**: `041-session-persistence` | **Date**: 2026-02-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/041-session-persistence/spec.md`

## Summary

Make the chat feel stateful across sessions by: (1) restoring PM conversation partners from the `private_messages` table on connect for registered users (ordered by recency, capped at 50), (2) auto-opening PM conversations in the treebar when incoming PMs arrive from contacts not yet in the list, and (3) automatically adding/removing channels to/from the auto-join list when users `/join` or `/part`. All changes leverage existing infrastructure — no new database tables or migrations needed, only a new Ecto query and behavioral changes in the LiveView layer.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro CSS framework, esbuild
**Storage**: PostgreSQL 16+ (existing `private_messages` table, existing `autojoin_list_entries` table — no new migrations)
**Testing**: ExUnit (unit, integration, liveview, e2e), Vitest + jsdom (JS)
**Target Platform**: Web (modern browsers)
**Project Type**: Umbrella app (retro_hex_chat domain + retro_hex_chat_web)
**Performance Goals**: PM conversation restore must not block mount; query should complete in <100ms for typical usage (≤50 partners)
**Constraints**: Max 50 PM partners restored, max 20 auto-join entries (existing limit), no new migrations
**Scale/Scope**: Typical user has 5-20 PM partners, up to hundreds possible. 6 files modified, 1 new query function, ~150 lines of new code.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | All changes in Elixir/Phoenix/LiveView. No JS frameworks. |
| II. Umbrella with Bounded Contexts | PASS | New query in `Chat.Queries` (domain layer). Behavioral changes in `ChatLive` helpers (web layer). No cross-boundary violations. |
| III. OTP Process Architecture | PASS | No new processes needed. Uses existing PubSub and GenServer infrastructure. |
| IV. Test-First Development | PASS | Unit tests for new query, integration tests for PM restore, LiveView tests for auto-open behavior, E2E for full flow. |
| V. Contracts and Behaviours | PASS | No new modules requiring behaviours. Extends existing `Queries` module. |
| VI. Static Analysis | PASS | `@spec` on all new public functions. Credo, Dialyzer, format enforced. |
| VII. Lean LiveViews | PASS | Query lives in domain layer. LiveView only wires restore result to assigns. |
| VIII. retro Design Fidelity | PASS | No UI changes — reuses existing treebar component and notification infrastructure. |
| IX. Hot/Cold Data Separation | PASS | PM partners queried from PostgreSQL (cold), held in-memory as `pm_conversations` list (hot). |
| X. Scalable Architecture | PASS | Query uses existing composite index `idx_pm_conversation`. Capped at 50 results. |
| XI. User-Facing Documentation | PASS | Help topics for PM persistence and auto-join behavior. |

No violations. Complexity Tracking table not needed.

## Project Structure

### Documentation (this feature)

```text
specs/041-session-persistence/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── internal.md      # Internal API contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/chat/
│   ├── queries.ex                            # MODIFIED: add list_pm_partners/2
│   └── help_topics/
│       ├── features.ex                       # MODIFIED: add PM persistence + auto-join help topics
│       └── commands.ex                       # MODIFIED: update /join, /part help with auto-join info
├── test/retro_hex_chat/chat/
│   └── queries_test.exs                      # MODIFIED: add PM partner query tests

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/live/chat_live/
│   ├── helpers/
│   │   ├── persistence.ex                    # MODIFIED: add PM conversation restore to load_persisted_data
│   │   └── pm.ex                             # MODIFIED: reorder pm_conversations on activity
│   ├── pubsub_handlers/
│   │   └── messages.ex                       # MODIFIED: auto-open PM conversation on incoming PM
│   └── command_dispatch.ex                   # MODIFIED: auto-add/remove auto-join on join/part
├── test/retro_hex_chat_web/live/
│   ├── session_persistence_test.exs          # NEW: LiveView tests for PM restore + auto-open
│   └── autojoin_auto_add_test.exs            # NEW: LiveView tests for auto-join on join/part
```

**Structure Decision**: Standard umbrella layout. New query in domain `Chat.Queries`, behavioral changes in web layer helpers and handlers. Two new test files for the new behaviors.
