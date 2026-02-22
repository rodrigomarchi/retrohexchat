# Implementation Plan: Keyboard Shortcuts & Chat Search

**Branch**: `025-shortcuts-chat-search` | **Date**: 2026-02-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/025-shortcuts-chat-search/spec.md`

## Summary

Centralized keyboard shortcut system with cheatsheet dialog, global dispatch, window navigation, and enhanced chat search with in-context highlighting, result navigation, filters (case-sensitive, regex, my-mentions), and database history search. Extends existing `KeyBindings` module and `SearchBar` component. New `SearchHighlightHook` for client-side DOM highlighting. Global `ShortcutDispatcherHook` with bubble-up pattern to coexist with per-element hooks.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Storage**: PostgreSQL 16+ (user_preferences.key_bindings JSON column — no new migration needed)
**Testing**: ExUnit (unit, integration, liveview, e2e tags), Floki for HTML, Mox for behaviours
**Target Platform**: Web browser (all modern browsers)
**Project Type**: Umbrella web application (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Search highlighting < 500ms after debounce, window switch < 100ms
**Constraints**: Only Ctrl+Shift+Key combinations for custom shortcuts (browser-safe), 300ms search debounce
**Scale/Scope**: 9 existing + 12 new shortcut actions, ~15 files modified, ~5 new files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Compliance | Notes |
|-----------|-----------|------------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All server logic in Elixir/Phoenix. JS hooks are minimal (keyboard capture, DOM highlighting) — within Constitution's "keyboard shortcuts only" JS exception. |
| II. Umbrella with Bounded Contexts | Yes | PASS | KeyBindings, Search, HelpTopics stay in `retro_hex_chat` domain. New components/hooks in `retro_hex_chat_web`. No cross-boundary violations. |
| III. OTP Process Architecture | No | N/A | No new GenServers needed. Shortcuts and search are session-scoped, not process-per-channel. |
| IV. Test-First Development | Yes | PASS | TDD for all new modules. Unit tests for KeyBindings registry, Search filters. LiveView tests for cheatsheet dialog, search highlighting events. E2E for shortcut dispatch. |
| V. Contracts and Behaviours | Yes | PASS | KeyBindings already defines contracts. New actions follow existing pattern. No new behaviours needed — extending existing ones. |
| VI. Static Analysis | Yes | PASS | @spec on all new public functions. Credo strict, Dialyxir, mix format enforced. |
| VII. Lean LiveViews | Yes | PASS | ChatLive delegates to KeyBindings and Search contexts. Cheatsheet is a function component. JS hooks minimal and isolated. |
| VIII. retro Design Fidelity | Yes | PASS | Cheatsheet dialog uses retro window styling. Search bar retains retro aesthetic. Yellow highlight via CSS class. |
| IX. Hot/Cold Data Separation | Yes | PASS | Search filters operate on in-memory DOM (hot). History search queries PostgreSQL (cold). Keybindings persist to user_preferences JSON. |
| X. Scalable Architecture | No | N/A | Feature is client-session scoped. No distributed state implications. |
| XI. User-Facing Documentation | Yes | PASS | Help topics for: cheatsheet dialog, search enhancements, window navigation shortcuts. Update existing keyboard shortcuts topic. |

**Gate result**: ALL PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/025-shortcuts-chat-search/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── events.md        # LiveView event contracts
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/chat/
│   ├── key_bindings.ex              # MODIFY: add 12 new actions, categories, registry API
│   ├── search.ex                    # MODIFY: add case-sensitive, regex, my-mentions filters
│   └── help_topics/
│       ├── keyboard_shortcuts.ex    # MODIFY: update with new shortcuts, cheatsheet reference
│       ├── search.ex                # NEW or MODIFY: search enhancements help topic
│       └── cheatsheet.ex            # NEW: cheatsheet dialog help topic
└── test/retro_hex_chat/chat/
    ├── key_bindings_test.exs        # MODIFY: tests for new actions, categories, registry
    └── search_test.exs              # MODIFY: tests for filters (case, regex, mentions)

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── search_bar.ex            # MODIFY: add filter toggles, error display, term memory
│   │   └── cheatsheet_dialog.ex     # NEW: keyboard shortcut cheatsheet component
│   └── live/chat_live/
│       ├── keyboard_events.ex       # MODIFY: add window navigation handlers, cheatsheet toggle
│       ├── search_events.ex         # MODIFY: add filter state, client-side highlight coordination
│       └── navigation_events.ex     # NEW: window_next, window_prev, window_select handlers
├── assets/js/hooks/
│   ├── shortcut_dispatcher_hook.js  # NEW: global keyboard listener with bubble-up dispatch
│   └── search_highlight_hook.js     # NEW: DOM text highlighting, scroll-to-match, clear
├── assets/js/app.js                 # MODIFY: register new hooks
└── test/
    ├── retro_hex_chat_web/live/
    │   ├── keyboard_shortcuts_test.exs  # NEW: cheatsheet, global dispatch tests
    │   ├── search_highlight_test.exs    # NEW: highlighting, navigation, filter tests
    │   └── window_navigation_test.exs   # NEW: Ctrl+Shift+]/[/1-9 tests
    └── retro_hex_chat_web/components/
        └── cheatsheet_dialog_test.exs   # NEW: component rendering tests
```

**Structure Decision**: Umbrella app structure preserved. Domain logic (KeyBindings registry, Search filters) in `retro_hex_chat`. Presentation (components, hooks, events) in `retro_hex_chat_web`. Two new JS hooks for global dispatch and search highlighting. One new component for cheatsheet dialog. Navigation events extracted to dedicated module to keep keyboard_events.ex focused.

## Complexity Tracking

> No constitution violations — this section is empty.
