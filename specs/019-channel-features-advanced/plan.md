# Implementation Plan: Channel Features Advanced

**Branch**: `019-channel-features-advanced` | **Date**: 2026-02-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/019-channel-features-advanced/spec.md`

## Summary

Extend RetroHexChat's channel system with advanced IRC features: a 5-tier user hierarchy (owner > operator > half-operator > voice > regular), 7 new channel modes (+n, +s, +p, +c, +R, +j, +K), and a `/knock` command for invite-only channel access requests. The implementation extends existing domain modules (Membership, Modes, Policy, Server) with new role atoms, mode flags, and rank-based permission enforcement while adding a single new command handler and database migration.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (1 migration: add `mode_join_throttle` column to `registered_channels` table) + in-memory GenServer state for channel modes, membership, join throttle timestamps
**Testing**: ExUnit with async: true, Mox, ExMachina, StreamData (for mode parsing), Floki (for nicklist component tests)
**Target Platform**: Web (Phoenix LiveView, all browsers)
**Project Type**: Umbrella web application (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Mode changes and permission checks must be sub-millisecond (all in-memory GenServer state). Join throttle uses in-process timestamp list (bounded by throttle count).
**Constraints**: No coupling between Channels and Services bounded contexts (pass `identified` flag as parameter, don't query NickServ from Server). All new modes persist for registered channels.
**Scale/Scope**: ~20 files modified, 1 new file (knock handler), 1 new migration. ~15 new/modified test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Elixir & Phoenix Exclusive Stack | PASS | Pure Elixir/Phoenix/LiveView. No JS frameworks. PostgreSQL only. retro design system. |
| II | Umbrella App with Bounded Contexts | PASS | All domain changes in `retro_hex_chat` (Channels, Commands contexts). Web changes in `retro_hex_chat_web`. No cross-context coupling. |
| III | OTP Process Architecture | PASS | Channel GenServer holds new mode state and join timestamps. No new processes needed. Knock is transient (PubSub broadcast, no state). |
| IV | Test-First Development | PASS | Unit tests for Membership, Modes, Policy (rank functions, new predicates, permission checks). Integration tests for Server (join/kick/ban with hierarchy). LiveView tests for nicklist grouping. |
| V | Contracts and Behaviours | PASS | `/knock` implements Handler behaviour. New Policy functions have @spec. Membership role type extended. |
| VI | Static Analysis from Day One | PASS | All new public functions have @spec. `mix credo --strict` and `mix dialyzer` enforced. |
| VII | Lean LiveViews & Component Architecture | PASS | LiveView delegates to Server/Policy for all permission logic. Nicklist component handles display grouping only. PubSub topics follow convention. |
| VIII | retro Design Fidelity | PASS | Nicklist extends existing retro-styled component. New CSS classes (nick-owner, nick-halfop) follow existing pattern. |
| IX | Hot/Cold Data Separation | PASS | Mode flags, membership, join timestamps: in-memory (hot). Mode persistence via `registered_channels` table (cold). Knock: transient PubSub only. |
| X | Scalable Architecture | PASS | Per-channel GenServer naturally distributes. No global state added. Join throttle is per-process (scales with channels). |
| XI | User-Facing Documentation | PASS | Help topics for all 9 new modes (+q, +h, +n, +s, +p, +c, +R, +j, +K) and /knock command. Updated overview topic. |

**Gate result**: ALL PASS — no violations.

**Post-Phase 1 re-check**: All design decisions maintain compliance. The `identified` parameter passed to `join/4` preserves bounded context separation (Principle II). Join throttle timestamps live in GenServer state (Principle IX). No new processes needed (Principle III).

## Project Structure

### Documentation (this feature)

```text
specs/019-channel-features-advanced/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: entity/struct changes
├── quickstart.md        # Phase 1: implementation order guide
├── contracts/           # Phase 1: API contracts
│   ├── channels-api.md  # Domain layer contracts
│   └── web-layer.md     # Web layer contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/
├── retro_hex_chat/                          # Domain layer
│   ├── lib/retro_hex_chat/
│   │   ├── channels/
│   │   │   ├── membership.ex               # MODIFY: add :owner, :half_operator roles, rank/1
│   │   │   ├── modes.ex                    # MODIFY: add 7 new flags, join_throttle field
│   │   │   ├── policy.ex                   # MODIFY: add can_kick?/3, can_ban?/2, can_set_mode?/3
│   │   │   ├── server.ex                   # MODIFY: hierarchy enforcement, +c/+n/+R/+j logic
│   │   │   └── queries.ex                  # MODIFY: load/save join_throttle
│   │   ├── commands/
│   │   │   ├── handler.ex                  # MODIFY: add half_operator_in to context type
│   │   │   ├── registry.ex                 # MODIFY: register "knock" handler
│   │   │   └── handlers/
│   │   │       ├── knock.ex                # NEW: /knock command handler
│   │   │       ├── mode.ex                 # MODIFY: half-op permission check
│   │   │       ├── kick.ex                 # MODIFY: half-op support
│   │   │       └── ban.ex                  # MODIFY: operator+ check
│   │   ├── services/
│   │   │   └── registered_channel.ex       # MODIFY: add mode_join_throttle field
│   │   └── chat/
│   │       └── help_topics/
│   │           └── channel_modes.ex        # MODIFY: add 10 new help topics
│   ├── priv/repo/migrations/
│   │   └── *_add_advanced_channel_modes.exs # NEW: add mode_join_throttle column
│   └── test/
│       └── retro_hex_chat/
│           ├── channels/
│           │   ├── membership_test.exs     # MODIFY: test new roles, rank
│           │   ├── modes_test.exs          # MODIFY: test new flags, mutual exclusivity
│           │   ├── policy_test.exs         # MODIFY: test rank-based permissions
│           │   └── server_test.exs         # MODIFY: test hierarchy, +c/+n/+R/+j
│           └── commands/handlers/
│               └── knock_test.exs          # NEW: test /knock command
└── retro_hex_chat_web/                     # Web layer
    ├── lib/retro_hex_chat_web/
    │   ├── components/
    │   │   └── nicklist.ex                 # MODIFY: 5 groups with ~ @ % + prefixes
    │   ├── live/
    │   │   ├── channel_list_live.ex        # MODIFY: filter +s/+p channels
    │   │   └── chat_live/
    │   │       ├── command_dispatch.ex     # MODIFY: operator_in includes owners, add half_operator_in
    │   │       ├── pubsub_handlers/
    │   │       │   └── channel_state.ex    # MODIFY: handle +q/+h/knock events
    │   │       ├── helpers/
    │   │       │   └── whois.ex            # MODIFY: filter +s channels from whois
    │   │       └── ui_actions/
    │   │           └── core.ex             # MODIFY: add :knock_channel action
    └── test/
        └── retro_hex_chat_web/
            ├── components/
            │   └── nicklist_test.exs       # MODIFY: test 5-group display
            └── live/
                └── channel_list_live_test.exs # MODIFY: test +s/+p filtering
```

**Structure Decision**: Existing umbrella structure. All domain logic in `retro_hex_chat`, all web/UI in `retro_hex_chat_web`. No new bounded contexts — extends Channels and Commands. One new migration. One new command handler module.

## Complexity Tracking

> No violations found — table not needed.
