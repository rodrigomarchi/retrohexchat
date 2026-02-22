# Implementation Plan: P2P Security, Help & Polish

**Branch**: `039-p2p-security-help-polish` | **Date**: 2026-02-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/039-p2p-security-help-polish/spec.md`

## Summary

Harden the existing P2P stack (features 034-038) with server-side rate limiting for session creation and signaling, add a TURN-only privacy mode preference with lobby UI toggle, integrate ignore/ban enforcement into active sessions, and add 4 mandatory help topics for P2P features. The TURN credential system already exists and only needs a TTL config change. No database migrations required.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, LiveView 1.0+, retro CSS framework, esbuild, ExSTUN ~> 0.1 (existing)
**Storage**: PostgreSQL 16+ (existing `user_preferences.message_settings` JSONB — no new migrations), ETS (rate limit state)
**Testing**: ExUnit (async, Mox, ExMachina), Vitest with jsdom
**Target Platform**: Web (modern browsers with WebRTC support)
**Project Type**: Umbrella (Elixir umbrella app with 2 applications)
**Performance Goals**: Rate limit checks <1ms (ETS lookup), no impact on existing P2P connection latency
**Constraints**: TURN shared secret never exposed client-side, all rate limiting server-side
**Scale/Scope**: ~12 files modified, ~3 new files, ~4 new help topics, ~0 migrations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All server logic in Elixir, no new JS frameworks |
| II. Umbrella with Bounded Contexts | Yes | PASS | Rate limiter stays in P2P context, help in Chat context |
| III. OTP Process Architecture | Yes | PASS | ETS table initialized in P2P Supervisor, no new GenServers needed |
| IV. Test-First Development | Yes | PASS | Unit tests for rate limiter, signaling rate limit, help topics; integration tests for LiveView |
| V. Contracts and Behaviours | Yes | PASS | Implements existing `SignalingRateLimit` behaviour with ETS module |
| VI. Static Analysis | Yes | PASS | @spec on all new public functions, Credo/Dialyzer/ESLint enforced |
| VII. Lean LiveViews | Yes | PASS | LiveView delegates to P2P context for rate limiting and preferences |
| VIII. retro Design Fidelity | Yes | PASS | Privacy mode checkbox uses retro design system checkbox styling |
| IX. Hot/Cold Data Separation | Yes | PASS | Rate limits in ETS (hot), preferences in PostgreSQL (cold) |
| X. Scalable Architecture | Yes | PASS | ETS rate limits are per-node; works with future clustering |
| XI. User-Facing Documentation | Yes | PASS | 4 new help topics + keyboard shortcuts update |

**Post-Phase 1 re-check**: All principles remain PASS. No violations introduced.

## Project Structure

### Documentation (this feature)

```text
specs/039-p2p-security-help-polish/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research findings
├── data-model.md        # Phase 1: data model
├── quickstart.md        # Phase 1: implementation guide
├── contracts/           # Phase 1: API contracts
│   ├── p2p-rate-limit.md
│   ├── privacy-mode.md
│   └── ignore-ban-integration.md
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                        # Domain layer
├── lib/retro_hex_chat/
│   ├── p2p/
│   │   ├── p2p.ex                          # MODIFY: add turn_configured?/0, close_sessions_between/2
│   │   ├── service.ex                      # MODIFY: add rate limit check in create_session
│   │   ├── policy.ex                       # MODIFY: update error message for blocked users
│   │   ├── queries.ex                      # MODIFY: add active_sessions_between/2 query
│   │   ├── supervisor.ex                   # MODIFY: init ETS table for rate limits
│   │   ├── rate_limiter.ex                 # NEW: sliding-window rate limiter
│   │   └── signaling_rate_limit/
│   │       └── ets.ex                      # NEW: ETS-based SignalingRateLimit impl
│   └── chat/
│       └── help_topics/
│           ├── features.ex                 # MODIFY: add 4 P2P help topics
│           └── keyboard_shortcuts.ex       # MODIFY: update with P2P shortcuts
├── test/retro_hex_chat/
│   └── p2p/
│       ├── rate_limiter_test.exs           # NEW
│       └── signaling_rate_limit/
│           └── ets_test.exs                # NEW
└── config/
    ├── config.exs                          # MODIFY: rate limiter config, TTL
    └── test.exs                            # MODIFY: test overrides

apps/retro_hex_chat_web/                    # Web layer
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── p2p_session_live.ex             # MODIFY: privacy mode, rate limit errors
│   └── components/
│       └── p2p_lobby.ex                    # MODIFY: privacy checkbox, TURN warning
├── assets/
│   ├── js/
│   │   ├── lib/webrtc.js                   # MODIFY: iceTransportPolicy option
│   │   └── hooks/webrtc_hook.js            # MODIFY: pass turn_only flag
│   └── test/
│       └── lib/webrtc.test.js              # MODIFY: add privacy mode test
└── test/retro_hex_chat_web/
    └── live/
        └── p2p_session_live_test.exs       # MODIFY: privacy mode, rate limit tests
```

**Structure Decision**: Existing umbrella structure. All P2P domain logic stays in `retro_hex_chat` app, web layer in `retro_hex_chat_web`. New modules follow established patterns within the P2P bounded context.

## Complexity Tracking

> No violations — no entries needed.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
