# Implementation Plan: User Information

**Branch**: `016-user-information` | **Date**: 2026-02-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/016-user-information/spec.md`

## Summary

Expand the existing `/whois` command to display comprehensive user information as text in the chat stream (shared channels, online time, idle time, registration status, bio). Add `/whowas` command with an in-memory ETS cache of recently disconnected users (1-hour TTL, 1000 max entries). Add `/bio` command for setting/viewing/clearing a user profile bio (max 200 chars, persisted for registered users). Track idle time per user via socket assigns (timestamp of last activity). Enable double-click on nicklist to trigger `/whois`.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (1 new table: `user_bios`) + in-memory ETS for whowas cache + socket assigns for idle tracking
**Testing**: ExUnit with async: true, LiveView tests, property-based tests for time formatting
**Target Platform**: Web (Phoenix LiveView)
**Project Type**: Umbrella (existing)
**Performance Goals**: /whois response < 2 seconds, idle drift < 30 seconds
**Constraints**: Whowas cache max 1000 entries, 1-hour TTL, bio max 200 graphemes
**Scale/Scope**: Existing codebase, 4 new command handlers, 1 new GenServer/ETS module, 1 migration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | All Elixir/Phoenix/PostgreSQL. No JS frameworks. |
| II. Umbrella Bounded Contexts | PASS | Bio in Chat context (like other profile data), WhowasCache in Presence context, commands in Commands context. |
| III. OTP Process Architecture | PASS | WhowasCache as a named GenServer backed by ETS. Idle tracking via socket assigns (no GenServer needed). |
| IV. Test-First Development | PASS | Tests for bio CRUD, whowas cache (insert/expire/evict), idle time formatting, whois output, /bio and /whowas handlers. |
| V. Contracts and Behaviours | PASS | /bio and /whowas implement Handler behaviour. /whois handler enhanced. |
| VI. Static Analysis | PASS | @spec on all public functions, Credo/Dialyzer enforced. |
| VII. Lean LiveViews | PASS | LiveView delegates to domain modules. New fields are socket assigns. Double-click via phx-click on nicklist. |
| VIII. retro Design Fidelity | PASS | No new UI dialogs — /whois output is text in chat stream (consistent with mIRC's /whois). |
| IX. Hot/Cold Data Separation | PASS | Bios in PostgreSQL (cold). Whowas cache + idle tracking in memory (hot). |
| X. Scalable Architecture | PASS | ETS table for whowas (fast lookup, bounded). Bio persisted in DB. |
| XI. User-Facing Documentation | PASS | Help topics for /whois (updated), /whowas (new), /bio (new). |

No violations. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/016-user-information/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── user-information.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── chat/
│   │   ├── user_bio.ex                    # Bio domain module (CRUD + persistence)
│   │   └── schemas/
│   │       └── user_bio.ex                # Ecto schema for user_bios table
│   ├── presence/
│   │   └── whowas_cache.ex               # GenServer + ETS for whowas entries
│   └── commands/handlers/
│       ├── whois.ex                       # Enhanced (existing)
│       ├── whowas.ex                      # New handler
│       └── bio.ex                         # New handler
├── priv/repo/migrations/
│   └── YYYYMMDD_create_user_bios.exs     # Migration for user_bios table
└── test/
    ├── retro_hex_chat/chat/user_bio_test.exs
    ├── retro_hex_chat/presence/whowas_cache_test.exs
    ├── retro_hex_chat/commands/handlers/whois_test.exs    # Enhanced
    ├── retro_hex_chat/commands/handlers/whowas_test.exs
    └── retro_hex_chat/commands/handlers/bio_test.exs

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/chat_live.ex                  # Enhanced: idle tracking, whois output, double-click
│   └── components/
│       └── nicklist.ex                    # Enhanced: double-click event
└── test/
    └── retro_hex_chat_web/live/
        ├── whois_test.exs                 # LiveView tests for expanded whois
        └── bio_test.exs                   # LiveView tests for /bio command
```

**Structure Decision**: Follows existing umbrella structure. Bio persistence in `Chat` context (alongside other user profile data like favorites, highlight words). WhowasCache in `Presence` context (alongside user tracking). Commands follow Handler behaviour pattern.
