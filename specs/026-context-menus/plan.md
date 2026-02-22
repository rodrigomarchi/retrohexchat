# Implementation Plan: Context Menus

**Branch**: `026-context-menus` | **Date**: 2026-02-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/026-context-menus/spec.md`

## Summary

Implement comprehensive right-click context menus for the chat area (nicknames, URLs, channels, general messages) and extend the existing treebar context menu. The approach leverages existing context menu infrastructure (retro styling, fixed positioning, phx-click events) with a new unified chat context menu component, enhanced JS hooks for element detection and keyboard navigation, and viewport repositioning logic. No new database migrations — mute state persists in the existing `user_preferences` JSON column.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Storage**: PostgreSQL 16+ (user_preferences.message_settings JSON column — no new migration needed)
**Testing**: ExUnit, Floki (HTML parsing), Wallaby (E2E)
**Target Platform**: Web (desktop browsers)
**Project Type**: Phoenix umbrella app (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Context menus appear within 200ms of right-click
**Constraints**: Zero JavaScript UI frameworks (LiveView + minimal JS hooks only)
**Scale/Scope**: 5 context menu types, ~30 menu item actions, 1 new component, 1 new JS hook, extensions to 4 existing files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All logic in Elixir/LiveView. JS hooks only for DOM concerns (keyboard nav, clipboard, viewport measurement). |
| II. Umbrella Bounded Contexts | Yes | PASS | Mute preference goes in `Chat.UserPreferences`. Menu components in web layer. No cross-boundary violations. |
| III. OTP Process Architecture | No | N/A | No new processes needed. Menus are UI-only. |
| IV. Test-First Development | Yes | PASS | Tests for each menu type, disabled states, op filtering, keyboard nav. TDD approach. |
| V. Contracts and Behaviours | Marginal | PASS | No new behaviours needed — menu items are not polymorphic command handlers. Event contracts documented in `contracts/`. |
| VI. Static Analysis | Yes | PASS | @spec on all public functions. Credo/Dialyzer/format enforced. |
| VII. Lean LiveViews | Yes | PASS | LiveView handles events by delegating to context functions. Menu rendering in function components. JS hooks minimal (keyboard nav, clipboard, viewport). |
| VIII. retro Design Fidelity | Yes | PASS | retro `.window` class, beveled borders, existing context menu styling. Keyboard navigation matches classic desktop behavior. |
| IX. Hot/Cold Data Separation | Yes | PASS | Menu state in socket assigns (hot). Mute preferences in PostgreSQL JSON (cold). |
| X. Scalable Architecture | No | N/A | UI feature, no scaling concerns. |
| XI. User-Facing Documentation | Yes | PASS | Help topic for context menus added to HelpTopics. Keyboard shortcuts topic updated. |

**Gate result**: PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/026-context-menus/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: data model
├── quickstart.md        # Phase 1: dev quickstart
├── contracts/           # Phase 1: event contracts
│   └── liveview-events.md
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/
│   └── chat/
│       └── user_preferences.ex               # MODIFY: add muted_channels helpers
└── test/retro_hex_chat/
    └── chat/
        └── user_preferences_test.exs         # MODIFY: test muted_channels

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── chat_context_menu.ex              # NEW: unified chat area context menu
│   │   ├── treebar_context_menu.ex           # MODIFY: extend with new items
│   │   └── context_menu.ex                   # MODIFY: add shortcut hint support
│   └── live/
│       └── chat_live/
│           ├── context_menu_events.ex        # MODIFY: add chat context menu handlers
│           ├── favorites_events.ex           # MODIFY: add treebar menu handlers
│           └── chat_live.ex                  # MODIFY: data attributes, assign init
│           └── chat_live.html.heex           # MODIFY: render chat context menu
├── assets/
│   ├── js/hooks/
│   │   ├── scroll_hook.js                    # MODIFY: replace copy menu with smart detection
│   │   └── context_menu_hook.js              # NEW: keyboard nav + viewport repositioning
│   └── css/
│       └── components.css                    # MODIFY: disabled/focused/shortcut styles
└── test/retro_hex_chat_web/
    └── live/
        └── chat_live/
            └── context_menu_test.exs         # MODIFY: extend with chat context menu tests
```

**Structure Decision**: Follows existing umbrella structure. One new component (`chat_context_menu.ex`), one new JS hook (`context_menu_hook.js`). All other changes are extensions to existing files.

## Complexity Tracking

> No constitution violations — this section is empty.
