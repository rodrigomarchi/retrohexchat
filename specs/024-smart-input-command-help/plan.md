# Implementation Plan: Smart Input & Command Help

**Branch**: `024-smart-input-command-help` | **Date**: 2026-02-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/024-smart-input-command-help/spec.md`

## Summary

Add intelligent command syntax guidance, contextual input behavior, and enhanced history navigation to the RetroHexChat chat input. The feature consists of four independently deliverable slices: (P1) an inline syntax tooltip that shows command parameters with live highlighting as users type, (P2) contextual placeholder text that reflects the active channel/PM/Status context, (P3) vertical input expansion up to 5 lines by converting `<input>` to `<textarea>`, and (P4) enhanced history with draft preservation (Ctrl+Up/Down), reverse search (Ctrl+R), and localStorage persistence. The implementation extends the existing Handler behaviour with structured syntax definitions, adds a new user preference for tooltip verbosity, and introduces three new JavaScript hooks while extending the existing AutocompleteHook.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro CSS framework, esbuild
**Storage**: PostgreSQL 16+ (user_preferences JSON column — no migration needed), localStorage (client-side history)
**Testing**: ExUnit with Mox, ExMachina, Floki for LiveView tests
**Target Platform**: Web (modern browsers, desktop-focused)
**Project Type**: Umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Tooltip appears within 200ms of command input, placeholder updates within 100ms of context switch
**Constraints**: Textarea max 5 visible lines, history max 100 entries, sensitive commands never persisted
**Scale/Scope**: 47 registered commands need syntax definitions, ~15 files modified, 3 new JS hooks, 2 new Elixir components

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Relevant | Status | Notes |
|---|-----------|----------|--------|-------|
| I | Elixir & Phoenix Exclusive Stack | Yes | PASS | All server logic in Elixir/Phoenix. JS hooks are minimal and isolated (Constitution VII allows keyboard/scroll hooks). No JS UI frameworks. |
| II | Umbrella with Bounded Contexts | Yes | PASS | CommandSyntax structs go in `RetroHexChat.Commands` context. Preference extension stays in `RetroHexChat.Chat`. Web components stay in web app. |
| III | OTP Process Architecture | No | N/A | No new processes needed — syntax data is compile-time, tooltip is request/response. |
| IV | Test-First Development | Yes | PASS | Tests written before implementation for all slices. Unit tests for structs, LiveView tests for events, E2E for integration. |
| V | Contracts and Behaviours | Yes | PASS | `syntax_definition/0` added as optional callback to Handler behaviour. CommandSyntax/Parameter/SubOption are typed structs with @spec. |
| VI | Static Analysis from Day One | Yes | PASS | All new public functions have @spec. Credo + Dialyzer + format enforced. |
| VII | Lean LiveViews & Components | Yes | PASS | LiveView delegates to Commands context for syntax data. Tooltip is a function component. JS hooks handle only positioning/keyboard/DOM. |
| VIII | retro Design Fidelity | Yes | PASS | Tooltip styled with retro conventions (sunken panel, system font). Textarea matches existing input styling. |
| IX | Hot/Cold Data Separation | Yes | PASS | Syntax data is compile-time (hot). Preferences in PostgreSQL (cold). Client history in localStorage (client-local). |
| X | Scalable Architecture | No | N/A | No architectural decisions that affect scaling. |
| XI | User-Facing Documentation | Yes | PASS | Help topics added for: Command Syntax Tooltip, Smart Input, Enhanced History, new keyboard shortcuts. |

**Post-Phase 1 Re-check**: All principles continue to pass. The `<input>` → `<textarea>` conversion is the only structural change, and it maintains all existing patterns (form submission, hook attachment, CSS styling).

## Project Structure

### Documentation (this feature)

```text
specs/024-smart-input-command-help/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 research decisions
├── data-model.md        # Entity definitions and state machines
├── quickstart.md        # Development guide
├── contracts/
│   └── liveview-events.md  # Event contracts (client ↔ server)
└── checklists/
    └── requirements.md     # Spec quality checklist
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── commands/
│   │   ├── handler.ex                    # MODIFIED — add syntax_definition/0 callback
│   │   ├── command_syntax.ex             # NEW — CommandSyntax, Parameter, SubOption structs
│   │   ├── registry.ex                   # MODIFIED — aggregate syntax definitions
│   │   ├── autocomplete.ex               # (unchanged)
│   │   └── handlers/
│   │       ├── mode.ex                   # MODIFIED — add syntax_definition/0
│   │       ├── kick.ex                   # MODIFIED — add syntax_definition/0
│   │       ├── join.ex                   # MODIFIED — add syntax_definition/0
│   │       ├── msg.ex                    # MODIFIED — add syntax_definition/0
│   │       ├── ban.ex                    # MODIFIED — add syntax_definition/0
│   │       └── ... (remaining handlers)  # MODIFIED — add syntax_definition/0 incrementally
│   └── chat/
│       ├── user_preferences.ex           # MODIFIED — add command_help_level
│       └── help_topics/
│           ├── features.ex               # MODIFIED — add 3 help topics
│           └── keyboard_shortcuts.ex     # MODIFIED — update shortcuts list
└── test/
    ├── retro_hex_chat/commands/
    │   └── command_syntax_test.exs       # NEW
    └── retro_hex_chat/chat/
        └── user_preferences_test.exs     # MODIFIED

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   ├── chat_live.ex                  # MODIFIED — tooltip assigns, placeholder
│   │   ├── chat_live.html.heex           # MODIFIED — textarea, tooltip, placeholder
│   │   └── chat_live/
│   │       ├── core_events.ex            # MODIFIED — tooltip events
│   │       └── options_events.ex         # MODIFIED — help level preference
│   └── components/
│       ├── syntax_tooltip.ex             # NEW — tooltip function component
│       ├── history_search.ex             # NEW — Ctrl+R search component
│       └── options_dialog.ex             # MODIFIED — add help level setting
├── assets/
│   ├── js/
│   │   ├── app.js                        # MODIFIED — register new hooks
│   │   └── hooks/
│   │       ├── autocomplete_hook.js      # MODIFIED — textarea compat, tooltip triggers
│   │       ├── input_history_hook.js     # NEW — enhanced history + persistence
│   │       └── input_resize_hook.js      # NEW — textarea auto-resize
│   └── css/
│       └── chat.css                      # MODIFIED — textarea, tooltip, search styling
└── test/
    └── retro_hex_chat_web/live/chat_live/
        ├── syntax_tooltip_test.exs       # NEW
        ├── smart_input_test.exs          # NEW
        └── enhanced_history_test.exs     # NEW
```

**Structure Decision**: Follows existing umbrella structure. Domain structs in `Commands` context (pure Elixir, no Phoenix deps). UI components in web app. JavaScript hooks are minimal and isolated per Constitution VII. No new bounded contexts needed.

## Complexity Tracking

No constitution violations to justify. All principles pass.
