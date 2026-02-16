# Implementation Plan: P2P Foundation

**Branch**: `034-p2p-foundation` | **Date**: 2026-02-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/034-p2p-foundation/spec.md`

## Summary

Build the foundational domain layer for peer-to-peer sessions in RetroHexChat. This introduces the 8th bounded context (`RetroHexChat.P2P`) with a `p2p_sessions` database table, a GenServer-per-session architecture (mirroring the existing ChannelServer pattern), session token management via Phoenix.Token, authorization policies enforcing registered-only access with block/ignore checks, and a periodic stale session cleanup task. No UI, no WebRTC, no commands — purely domain infrastructure.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, Phoenix.Token (already in use)
**Storage**: PostgreSQL 16+ (1 new migration: `p2p_sessions` table)
**Testing**: ExUnit (unit, integration), Mox for behaviours, ExMachina for factories
**Target Platform**: Linux/macOS server (self-hosted)
**Project Type**: Umbrella app — new code goes in `retro_hex_chat` domain app only
**Performance Goals**: Session creation + state transitions < 1s processing, auth checks < 100ms
**Constraints**: Domain app must NOT depend on Phoenix/web concerns (Constitution II)
**Scale/Scope**: 1 new table, ~10 new modules, ~200-400 LOC domain + ~300-500 LOC tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | Pure Elixir domain modules, PostgreSQL storage |
| II. Umbrella Bounded Contexts | Yes | PASS | New `RetroHexChat.P2P` context with internal layering (Schema, Queries, Service, Policy) |
| III. OTP Process Architecture | Yes | PASS | GenServer per session, DynamicSupervisor, Registry via_tuple — mirrors ChannelServer |
| IV. Test-First Development | Yes | PASS | TDD with unit + integration tests, ExMachina factories |
| V. Contracts and Behaviours | Yes | PASS | @spec on all public functions, Dialyzer-verified |
| VI. Static Analysis | Yes | PASS | Credo, Dialyxir, mix format enforced |
| VII. Lean LiveViews | N/A | — | No LiveView code in this plan (domain only) |
| VIII. Windows 98 Fidelity | N/A | — | No UI in this plan |
| IX. Hot/Cold Data Separation | Yes | PASS | GenServer = hot cache, PostgreSQL = authoritative cold store |
| X. Scalable Architecture | Yes | PASS | Process-per-session scales via DynamicSupervisor, DB indexed for lookups |
| XI. User Documentation | N/A | — | No user-facing features (infrastructure only); help topics deferred to command/UI plans |

**Gate result**: PASS — all relevant principles satisfied, no violations.

## Project Structure

### Documentation (this feature)

```text
specs/034-p2p-foundation/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── p2p-api.md       # Internal Elixir API contracts
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   └── p2p/                          # New bounded context
│       ├── p2p.ex                    # Facade module (public API)
│       ├── service.ex                # Orchestration (create, join, close)
│       ├── policy.ex                 # Authorization rules
│       ├── session_server.ex         # GenServer per session (state machine)
│       ├── session_token.ex          # Phoenix.Token sign/verify wrapper
│       ├── supervisor.ex             # DynamicSupervisor for sessions
│       ├── registry.ex               # Registry helpers (via_tuple, lookup)
│       ├── queries.ex                # Ecto queries for p2p_sessions
│       ├── cleanup_task.ex           # Periodic stale session cleanup
│       └── schema/
│           └── session.ex            # Ecto schema for p2p_sessions
├── priv/repo/migrations/
│   └── YYYYMMDDHHMMSS_create_p2p_sessions.exs
└── test/retro_hex_chat/
    └── p2p/
        ├── service_test.exs          # Service orchestration tests
        ├── policy_test.exs           # Authorization rule tests
        ├── session_server_test.exs   # GenServer state machine tests
        ├── session_token_test.exs    # Token sign/verify tests
        ├── queries_test.exs          # Database query tests
        ├── cleanup_task_test.exs     # Cleanup task tests
        └── schema/
            └── session_test.exs      # Schema changeset tests
```

**Structure Decision**: All new code goes in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/` following the established bounded context pattern. The `schema/` subdirectory mirrors the convention used by Chat context. No web-layer code in this plan.

## Complexity Tracking

> No violations — all constitution gates pass. No complexity justifications needed.
