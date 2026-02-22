# Implementation Plan: Notice System

**Branch**: `011-notice-system` | **Date**: 2026-02-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/011-notice-system/spec.md`

## Summary

Implement IRC-style NOTICE as a lightweight, transient message type for RetroHexChat. Two new `/` commands (`/notice`, `/notice_routing`) enable users to send notices to users and channels with distinct `-Nick-` formatting, configurable routing (active/status/sender window), and strict negative constraints (no PM windows, no sounds, no auto-replies). Notices are delivered via PubSub, never persisted to the database. Routing preferences are stored in the Session struct (in-memory for guests) and persisted to PostgreSQL for registered users.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (1 new table: `notice_routing_settings`) + in-memory Session state for guests
**Testing**: ExUnit with async: true, Mox, ExMachina, Floki
**Target Platform**: Web (Phoenix LiveView)
**Project Type**: Umbrella app (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Notice delivery < 1 second end-to-end (PubSub broadcast)
**Constraints**: Notices are transient — zero database writes for notice messages. Only the routing preference is persisted.
**Scale/Scope**: Standard chat scale. No new GenServers — notices are fire-and-forget via PubSub.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Elixir & Phoenix Exclusive Stack | PASS | Pure Elixir + Phoenix LiveView. No JS frameworks. PostgreSQL for persistence. retro design system for styling. |
| II | Umbrella App with Bounded Contexts | PASS | Domain logic in `retro_hex_chat` (Commands context for handlers, Chat context for notice routing settings). Web layer in `retro_hex_chat_web` (ChatLive handle_info, ChatMessage component). |
| III | OTP Process Architecture | PASS | No new GenServers needed. Channel notices use existing Channel.Server broadcast. User notices use existing `user:#{nickname}` PubSub topic. |
| IV | Test-First Development | PASS | Unit tests for handlers, routing logic, ignore integration. Integration tests for persistence. LiveView tests for rendering and routing. |
| V | Contracts and Behaviours | PASS | Both `/notice` and `/notice_routing` handlers implement existing `Handler` behaviour. |
| VI | Static Analysis from Day One | PASS | `@spec` on all public functions. Credo/Dialyxir compliance. |
| VII | Lean LiveViews & Component Architecture | PASS | ChatLive only handles PubSub routing. Notice formatting delegated to ChatMessage component. PubSub topics follow convention: `user:#{nickname}`, `channel:#{name}`. |
| VIII | retro Design Fidelity | PASS | Notice rendering uses retro design system-compatible styling. New `.chat-notice` CSS class with distinct color. `-Nick-` prefix follows retro IRC convention. |
| IX | Hot/Cold Data Separation | PASS | Notices are hot data only (transient PubSub messages, never persisted). Routing preference is cold data (persisted for registered users). |
| X | Scalable Architecture | PASS | PubSub-based delivery scales with Phoenix PubSub (pg adapter). No new state to manage. |
| XI | User-Facing Documentation | PASS | Help topics for `/notice` command, `/notice_routing` command, and "Notices" feature topic. |

**Gate result**: ALL PASS. No violations to track.

## Project Structure

### Documentation (this feature)

```text
specs/011-notice-system/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── notice-api.md    # Internal API contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── commands/
│   │   ├── handlers/
│   │   │   ├── notice.ex              # /notice command handler (NEW)
│   │   │   └── notice_routing.ex      # /notice_routing command handler (NEW)
│   │   └── registry.ex               # Add "notice" + "notice_routing" entries
│   ├── chat/
│   │   ├── notice_routing.ex          # Domain module for routing preference CRUD + persistence (NEW)
│   │   ├── schemas/
│   │   │   └── notice_routing_setting.ex  # Ecto schema for DB persistence (NEW)
│   │   ├── ignore_entry.ex            # Add :notices to valid types
│   │   └── ignore_list.ex             # Add type_matches?(:notices, :notice) clause
│   ├── accounts/
│   │   └── session.ex                 # Add notice_routing field
│   └── chat/
│       └── help_topics.ex             # Add notice help topics
├── priv/repo/migrations/
│   └── 2026MMDD_create_notice_routing_settings.exs  # Migration (NEW)
└── test/
    ├── retro_hex_chat/
    │   ├── commands/handlers/notice_test.exs          # (NEW)
    │   ├── commands/handlers/notice_routing_test.exs   # (NEW)
    │   └── chat/notice_routing_test.exs               # (NEW)
    └── ...

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── chat_live.ex               # Add handle_info for :new_notice, handle_dispatch_result for :notice
│   └── components/
│       └── chat_message.ex            # Add :notice type rendering with -Nick- prefix
├── assets/css/
│   └── layout.css                     # Add .chat-notice CSS class
└── test/
    └── retro_hex_chat_web/
        └── live/chat_live_notice_test.exs  # LiveView tests (NEW)
```

**Structure Decision**: Existing umbrella structure. New files follow established patterns (handler per command, domain module per feature, schema per table). No new bounded contexts needed — notices fit naturally into `Chat` (routing settings) and `Commands` (handlers).

## Complexity Tracking

> No violations detected. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
