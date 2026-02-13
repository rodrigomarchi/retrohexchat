# Implementation Plan: Autocomplete System

**Branch**: `023-autocomplete-system` | **Date**: 2026-02-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/023-autocomplete-system/spec.md`

## Summary

Unified autocomplete system for commands, nicknames, and channels. Enhances the existing command palette with fuzzy search, categories, and recent commands. Adds new `@` and `#` triggers for nick/channel autocomplete dropdowns. Adds IRC-style Tab-cycling for nick completion. Implements context-aware argument completion for commands like `/join`, `/msg`, `/kick`. All dropdowns share 98.css-styled UI with keyboard navigation. The architecture splits into: (1) a domain-level `Autocomplete` module for fuzzy matching and data aggregation, (2) enhanced LiveView components for rendering, (3) a unified JS hook replacing the current `CommandPaletteHook` with cursor-aware trigger detection.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css, esbuild
**Storage**: localStorage (recent commands client-side), PostgreSQL (no new tables — all data from existing Presence/Channels)
**Testing**: ExUnit (unit, integration, liveview, e2e tags), Mox, Floki
**Target Platform**: Web browser (Phoenix LiveView)
**Project Type**: Umbrella web application (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: <100ms autocomplete response for nick suggestions in 50+ user channels
**Constraints**: No new database migrations. All autocomplete data sourced from existing runtime state (Presence, Channel Registry, Command Registry). localStorage for recent commands.
**Scale/Scope**: 45 commands, up to 50+ users per channel, up to 100+ channels

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | Pure Elixir + LiveView + minimal JS hooks. No JS frameworks. |
| II. Umbrella Bounded Contexts | Yes | PASS | Domain logic in `retro_hex_chat` (new Autocomplete context under Commands or Chat). Web rendering in `retro_hex_chat_web`. |
| III. OTP Process Architecture | Marginal | PASS | No new GenServers needed. Leverages existing Channel Registry, Presence Tracker. |
| IV. Test-First Development | Yes | PASS | Tests written first for fuzzy matching, category mapping, autocomplete triggers, Tab cycling. |
| V. Contracts and Behaviours | Yes | PASS | Autocomplete providers can follow a common pattern. Handler.help() already provides command metadata. |
| VI. Static Analysis | Yes | PASS | @spec on all new public functions. Credo/Dialyzer enforced. |
| VII. Lean LiveViews | Yes | PASS | LiveView delegates to domain context for matching/filtering. Components handle rendering only. JS hook is minimal (trigger detection, cursor management). |
| VIII. Windows 98 Design Fidelity | Yes | PASS | Dropdowns use 98.css window/tree-view styling. Consistent with existing command palette. |
| IX. Hot/Cold Data Separation | Yes | PASS | All autocomplete data is hot (Presence, Channel GenServers, Command Registry). No cold storage queries for autocomplete. |
| X. Scalable Architecture | Marginal | PASS | In-memory matching scales with existing data. No new bottlenecks introduced. |
| XI. User-Facing Documentation | Yes | PASS | Help topic required for autocomplete feature + keyboard shortcuts update. |

**Gate result**: ALL PASS — no violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/023-autocomplete-system/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── autocomplete-events.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                              # Domain layer
├── lib/retro_hex_chat/
│   └── commands/
│       ├── registry.ex                           # MODIFY: add category metadata, fuzzy matching
│       └── autocomplete.ex                       # NEW: fuzzy match, nick/channel data aggregation
└── test/retro_hex_chat/
    └── commands/
        ├── registry_test.exs                     # MODIFY: test category mapping
        └── autocomplete_test.exs                 # NEW: fuzzy matching, filtering, ranking tests

apps/retro_hex_chat_web/                          # Web layer
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── command_palette.ex                    # MODIFY → autocomplete_dropdown.ex: unified dropdown component
│   └── live/chat_live/
│       ├── menu_toolbar_events.ex                # MODIFY: enhance palette events, add autocomplete events
│       └── core_events.ex                        # MODIFY: enhance tab_complete with cycling
├── assets/js/hooks/
│   └── command_palette_hook.js                   # MODIFY → autocomplete_hook.js: unified trigger detection
├── assets/css/
│   └── components.css                            # MODIFY: autocomplete dropdown styles
└── test/retro_hex_chat_web/
    ├── components/
    │   └── autocomplete_dropdown_test.exs        # NEW: replaces command_palette_test.exs
    └── live/
        └── autocomplete_test.exs                 # NEW: integration tests for autocomplete flows

apps/retro_hex_chat/lib/retro_hex_chat/chat/
└── help_topics/
    └── features.ex                               # MODIFY: add autocomplete help topic
```

**Structure Decision**: Follows existing umbrella separation. Domain logic (fuzzy matching, data aggregation, category mapping) goes in `retro_hex_chat/commands/autocomplete.ex`. Web rendering (dropdown component, event handlers, JS hook) stays in `retro_hex_chat_web`. No new bounded context needed — autocomplete is a cross-cutting concern that queries existing contexts (Commands, Presence, Channels).

## Complexity Tracking

> No constitution violations — table not needed.
