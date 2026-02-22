# Implementation Plan: Quote/Reply & Message Edit/Delete

**Branch**: `033-message-interactions` | **Date**: 2026-02-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/033-message-interactions/spec.md`

## Summary

Add message reply, edit, and delete capabilities to RetroHexChat. Users can reply to any message (creating a visual quote block), edit their own messages via ↑ key (within 5 minutes), and soft-delete their own messages via context menu (within 5 minutes). All operations are enforced server-side. The implementation extends the existing Message and PrivateMessage schemas with reply reference, edit timestamp, and soft-delete fields, adds new Chat.Service functions, and enhances the ChatLive UI with reply compose bar, edit mode, and delete confirmation.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Storage**: PostgreSQL 16+ (new columns on `messages` and `private_messages` tables — 1 migration)
**Testing**: ExUnit (unit, integration, liveview, e2e), Vitest + jsdom (JS hooks/lib)
**Target Platform**: Web (Phoenix LiveView)
**Project Type**: Umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Edit/delete operations visible to all viewers within 1 second; scroll-to-message within 500ms
**Constraints**: 5-minute time window enforced server-side; 3-second edit debounce; soft-delete only
**Scale/Scope**: Extends 2 existing schemas, adds ~6 new files, modifies ~14 existing files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | All logic in Elixir/Phoenix. JS limited to DOM wiring (hooks). |
| II. Umbrella Bounded Contexts | PASS | Domain logic in `retro_hex_chat` (Chat context). Web layer in `retro_hex_chat_web`. |
| III. OTP Process Architecture | PASS | Edit/delete routed through existing Channel GenServer. No new processes needed. |
| IV. Test-First Development | PASS | Tests for Policy, Queries, Service, LiveView, and JS hooks/lib. |
| V. Contracts and Behaviours | PASS | No new "/" commands. Existing patterns preserved. |
| VI. Static Analysis | PASS | @spec on all new public functions. ESLint + Prettier for JS. |
| VII. Lean LiveViews | PASS | LiveView delegates to Chat.Service. Components handle rendering. |
| VIII. retro Design Fidelity | PASS | retro styling for reply blocks, edit indicators, delete dialog. |
| IX. Hot/Cold Data Separation | PASS | Edit/delete persisted in PostgreSQL. Edit mode is ephemeral (socket assigns). |
| X. Scalable Architecture | PASS | PubSub broadcasts for real-time sync. No architectural dead-ends. |
| XI. User-Facing Documentation | PASS | Help topics for reply, edit, delete features. |

**Post-Phase 1 Re-check**: All principles satisfied. No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/033-message-interactions/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: Research decisions
├── data-model.md        # Phase 1: Entity changes
├── quickstart.md        # Phase 1: Implementation guide
├── contracts/
│   └── chat-service.md  # Phase 1: API contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/chat/
│   ├── message.ex                            # MODIFY: Add reply/edit/delete fields + changesets
│   ├── private_message.ex                    # MODIFY: Same as message.ex
│   ├── queries.ex                            # MODIFY: Add get, update, soft-delete, reply queries
│   ├── service.ex                            # MODIFY: Add edit_message, delete_message, extend send
│   ├── policy.ex                             # MODIFY: Add can_edit?/2, can_delete?/2
│   └── help_topics/
│       └── features.ex                       # MODIFY: Add reply, edit, delete help topics
├── priv/repo/migrations/
│   └── YYYYMMDDHHMMSS_add_message_interactions.exs  # NEW: Migration
└── test/retro_hex_chat/chat/
    ├── message_test.exs                      # MODIFY: Test new fields/changesets
    ├── queries_test.exs                      # MODIFY: Test new query functions
    ├── service_test.exs                      # MODIFY: Test edit/delete/reply service
    └── policy_test.exs                       # MODIFY: Test can_edit?/can_delete?

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── chat_message.ex                   # MODIFY: Reply blocks, (editado) tag, deleted display
│   │   ├── chat_context_menu.ex              # MODIFY: Enable reply, add delete item
│   │   ├── reply_compose_bar.ex              # NEW: Reply compose bar component
│   │   └── delete_confirm_dialog.ex          # NEW: Delete confirmation dialog
│   └── live/chat_live/
│       ├── core_events.ex                    # MODIFY: Handle edit/delete/reply events
│       └── pubsub_handlers/
│           └── messages.ex                   # MODIFY: Handle message_edited, message_deleted
├── assets/
│   ├── css/
│   │   ├── app.css                           # MODIFY: Import message-interactions.css
│   │   └── message-interactions.css          # NEW: Reply blocks, edit mode, deleted style
│   ├── js/
│   │   ├── hooks/
│   │   │   ├── keyboard_hook.js              # MODIFY: Add edit-mode trigger
│   │   │   └── message_interactions_hook.js  # NEW: Scroll-to, edit mode DOM, hover button
│   │   └── lib/
│   │       └── message_interactions.js       # NEW: Pure logic for interactions
│   └── test/
│       ├── hooks/
│       │   └── message_interactions_hook.test.js  # NEW: Hook tests
│       └── lib/
│           └── message_interactions.test.js       # NEW: Lib tests
└── test/retro_hex_chat_web/live/
    └── chat_live_test.exs                    # MODIFY: E2E tests for reply/edit/delete
```

**Structure Decision**: Follows the existing umbrella structure. Domain logic (schema, queries, service, policy) in `retro_hex_chat`. UI (components, LiveView events, hooks, CSS) in `retro_hex_chat_web`. JS follows the "hook = wiring, lib = logic" pattern per Constitution IV.

## Complexity Tracking

> No violations — no entries needed.
