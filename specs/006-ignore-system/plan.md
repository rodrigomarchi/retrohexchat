# Implementation Plan: Ignore System

**Branch**: `006-ignore-system` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-ignore-system/spec.md`

## Summary

Client-side ignore system allowing users to locally filter unwanted messages by nickname. Supports five ignore types (all/messages/pms/invites/actions), temporary timed ignores with auto-expiry, `/ignore` and `/unignore` commands, a standalone 98.css dialog for visual management, context menu integration, and persistence for registered users via the existing NickServ identify pattern.

The system operates entirely in the LiveView process — ignored messages are still delivered by the server but filtered before display in `handle_info` clauses. This follows the IRC convention where ignore is a client feature. Timer management uses `Process.send_after` in the LiveView process with refs stored in socket assigns.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
**Storage**: PostgreSQL 16+ (new `ignore_list_entries` table) + in-memory Session state for guests
**Testing**: ExUnit (unit, integration, liveview, e2e tags), Floki for HTML assertions
**Target Platform**: Web (Phoenix LiveView)
**Project Type**: Umbrella app (retro_hex_chat domain + retro_hex_chat_web)
**Performance Goals**: Sub-millisecond ignore check per message (in-memory list lookup)
**Constraints**: Max 100 ignore entries per user; timer precision at second level
**Scale/Scope**: Per-user ignore list, no cross-user or server-side impact

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | Pure Elixir domain, LiveView UI, PostgreSQL persistence, 98.css dialog |
| II. Umbrella with Bounded Contexts | PASS | IgnoreEntry/IgnoreList in Chat context (message filtering), Ecto schema in Chat schemas, web layer in ChatLive + new component |
| III. OTP Process Architecture | PASS | No new GenServers needed — ignore is per-session state in LiveView process. Timers via `Process.send_after` in LiveView |
| IV. Test-First Development | PASS | Unit tests for IgnoreEntry/IgnoreList, integration for persistence, LiveView tests for filtering/commands/dialog, E2E for full flows |
| V. Contracts and Behaviours | PASS | `/ignore` and `/unignore` handlers implement existing Handler behaviour |
| VI. Static Analysis | PASS | @spec on all public functions, Credo strict, Dialyxir clean |
| VII. Lean LiveViews | PASS | All CRUD in Chat.IgnoreList domain module; LiveView only calls domain + updates assigns |
| VIII. Windows 98 Fidelity | PASS | IgnoreListDialog uses 98.css window, sunken-panel table, standard button layout |
| IX. Hot/Cold Data Separation | PASS | Runtime ignore list in Session (hot); PostgreSQL for persistence (cold) |
| X. Scalable Architecture | PASS | Per-session state, no shared mutable state, no GenServer bottleneck |
| XI. User-Facing Documentation | PASS | Help topics for /ignore command, /unignore command, Ignore List feature, Keyboard Shortcuts updated |

**Gate result: ALL PASS** — No violations.

## Project Structure

### Documentation (this feature)

```text
specs/006-ignore-system/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── ignore-list-api.md
│   └── command-syntax.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/
│   ├── chat/
│   │   ├── ignore_entry.ex                   # NEW: In-memory struct
│   │   ├── ignore_list.ex                    # NEW: CRUD + persistence
│   │   ├── schemas/
│   │   │   └── ignore_list_entry.ex          # NEW: Ecto schema
│   │   └── help_topics.ex                    # MODIFY: Add ignore topics
│   ├── commands/
│   │   ├── handlers/
│   │   │   ├── ignore.ex                     # NEW: /ignore handler
│   │   │   └── unignore.ex                   # NEW: /unignore handler
│   │   └── registry.ex                       # MODIFY: Register commands
│   └── accounts/
│       └── session.ex                        # MODIFY: Add ignore_list field
├── priv/repo/migrations/
│   └── 20260211180000_create_ignore_list.exs # NEW: Migration
└── test/retro_hex_chat/
    ├── chat/
    │   ├── ignore_entry_test.exs             # NEW
    │   ├── ignore_list_test.exs              # NEW
    │   └── ignore_list_persistence_test.exs  # NEW
    └── commands/handlers/
        ├── ignore_test.exs                   # NEW
        └── unignore_test.exs                 # NEW

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── chat_live.ex                      # MODIFY: Filtering + events
│   └── components/
│       ├── ignore_list_dialog.ex             # NEW: 98.css dialog
│       └── context_menu.ex                   # MODIFY: Add Ignore option
└── test/retro_hex_chat_web/
    ├── live/
    │   ├── chat_live_ignore_test.exs         # NEW: LiveView integration
    │   └── chat_live_ignore_e2e_test.exs     # NEW: E2E tests
    └── components/
        └── ignore_list_dialog_test.exs       # NEW: Component tests
```

**Structure Decision**: Existing Phoenix umbrella structure. IgnoreEntry/IgnoreList placed in Chat bounded context (message filtering concern). Ecto schema under Chat schemas. Standalone IgnoreListDialog component (not embedded in Address Book — that is explicitly out of scope per spec).

## Complexity Tracking

> No violations to justify — all constitution checks pass.
