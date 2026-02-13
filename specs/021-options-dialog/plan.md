# Implementation Plan: Options Dialog

**Branch**: `021-options-dialog` | **Date**: 2026-02-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/021-options-dialog/spec.md`

## Summary

Centralized Options dialog (Alt+O) serving as the single hub for all user preferences. Windows 98-style dialog with tree-view navigation (left) and settings panel (right). Six panels: Connect, IRC Messages, Display, Fonts, Colors, Key Bindings. Uses a draft state pattern (Apply/OK/Cancel) matching existing SoundSettingsDialog. Introduces CSS custom properties for real-time font and color customization. Refactors hardcoded keyboard shortcuts to a dynamic lookup system. Persists all preferences in a single `user_preferences` table with JSONB columns.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
**Storage**: PostgreSQL 16+ (1 new table: `user_preferences` with 6 JSONB columns) + in-memory Session state for guests
**Testing**: ExUnit (unit, integration, LiveView, E2E), Floki for HTML parsing
**Target Platform**: Web browser (desktop)
**Project Type**: Umbrella web application (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Font/color changes apply within 1 second of Apply click, no page reload
**Constraints**: Modeless dialog (no chat blocking), CSS custom properties for instant visual updates
**Scale/Scope**: 6 panels, ~22 configurable settings, 9 default key bindings, 24-color palette, 5 font families

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
| --------- | ------ | ----- |
| I. Elixir & Phoenix Exclusive | PASS | All Elixir/Phoenix/LiveView. JS hooks limited to CSS property updates and key capture — no UI frameworks. |
| II. Umbrella Bounded Contexts | PASS | `UserPreferences` and `KeyBindings` in `retro_hex_chat` (Chat context). `OptionsDialog` component and `OptionsEvents` handler in `retro_hex_chat_web`. |
| III. OTP Process Architecture | PASS | No new GenServers needed. Preferences are per-user session state, not shared process state. |
| IV. Test-First Development | PASS | TDD for all domain modules (UserPreferences, KeyBindings), component tests, integration tests, E2E tests. |
| V. Contracts and Behaviours | PASS | No new "/" commands. Event contracts documented in contracts/liveview-events.md. |
| VI. Static Analysis | PASS | @spec on all public functions. Credo strict, Dialyxir, mix format enforced. |
| VII. Lean LiveViews | PASS | OptionsDialog is a function component. All logic delegated to UserPreferences/KeyBindings domain modules. OptionsEvents handler is thin. |
| VIII. Windows 98 Design Fidelity | PASS | Tree-view uses 98.css `.tree-view` class. Dialog uses standard 98.css `.window` pattern. Color picker uses 4×6 grid matching existing formatting toolbar approach. |
| IX. Hot/Cold Data Separation | PASS | Runtime preferences in Session (hot). Persistence in PostgreSQL `user_preferences` table (cold). |
| X. Scalable Architecture | PASS | Per-user row in `user_preferences` table. No shared state concerns. |
| XI. User-Facing Documentation | PASS | Help topics planned for Options dialog, all 6 panels, keyboard shortcuts update. |

**Post-Phase 1 Re-check**: All principles still pass. The CSS custom properties strategy introduces a JS hook but stays within the "minimal and isolated" JavaScript hooks guideline from Principle VII.

## Project Structure

### Documentation (this feature)

```text
specs/021-options-dialog/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: data model
├── quickstart.md        # Phase 1: implementation guide
├── contracts/
│   └── liveview-events.md  # Phase 1: event contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/
│   ├── chat/
│   │   ├── user_preferences.ex               # NEW: In-memory CRUD + persistence
│   │   ├── key_bindings.ex                   # NEW: Default bindings, validation, lookup
│   │   └── schemas/
│   │       └── user_preference.ex            # NEW: Ecto schema (6 JSONB columns)
│   └── accounts/
│       └── session.ex                        # MODIFIED: Add user_preferences field
├── priv/repo/migrations/
│   └── NNNN_create_user_preferences.exs      # NEW: Migration
└── test/retro_hex_chat/
    ├── chat/user_preferences_test.exs        # NEW: Unit + integration tests
    └── chat/key_bindings_test.exs            # NEW: Unit tests

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── options_dialog.ex                 # NEW: Options dialog component
│   └── live/chat_live/
│       ├── options_events.ex                 # NEW: Event handlers (~20 events)
│       ├── keyboard_events.ex                # MODIFIED: Dynamic lookup refactor
│       └── menu_toolbar_events.ex            # MODIFIED: Wire settings button
├── assets/
│   ├── js/hooks/
│   │   ├── options_hook.js                   # NEW: CSS custom property updater
│   │   ├── key_binding_capture_hook.js       # NEW: Key capture for bindings panel
│   │   └── reconnect_hook.js                # MODIFIED: Accept dynamic config
│   └── css/
│       ├── layout.css                        # MODIFIED: Add CSS custom properties
│       ├── chat.css                          # MODIFIED: Replace hardcoded with var()
│       └── components.css                    # MODIFIED: Replace hardcoded with var()
└── test/retro_hex_chat_web/live/
    ├── chat_live_options_test.exs             # NEW: LiveView tests
    └── chat_live_options_e2e_test.exs         # NEW: E2E tests
```

**Structure Decision**: Existing Phoenix umbrella structure. New domain modules in `Chat` bounded context (UserPreferences manages preferences data, KeyBindings manages shortcut mappings). New web component + event handler module following established patterns.

## Complexity Tracking

> No constitution violations. All principles pass.
