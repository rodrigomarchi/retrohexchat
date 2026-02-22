# Implementation Plan: P2P Actions in Context Menus

**Branch**: `040-p2p-context-menus` | **Date**: 2026-02-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/040-p2p-context-menus/spec.md`

## Summary

Add four P2P action items ("Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", "Enviar Arquivo") to both the nicklist and chat nick context menus. Items are visible only for identified (registered) users, disabled when the target is unregistered or self, and create P2P sessions by reusing existing `P2p.do_execute/3`. The initiator is navigated to the P2P lobby via `push_navigate`. No new database tables, no new dependencies — purely UI wiring to existing P2P infrastructure.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+, JavaScript ES2020+
**Primary Dependencies**: Phoenix 1.8+, LiveView 1.0+, retro CSS framework, esbuild
**Storage**: N/A — no new migrations, all state is ephemeral (socket assigns)
**Testing**: ExUnit (LiveView tests, unit tests), Vitest (if JS changes needed)
**Target Platform**: Web browser (desktop, any modern browser)
**Project Type**: Umbrella (Phoenix)
**Performance Goals**: Context menu opens instantly; P2P session creation < 500ms
**Constraints**: No new npm or Elixir dependencies
**Scale/Scope**: 2 component files modified, 1 event handler module extended, ~150 lines of new code + tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | Pure Elixir + LiveView, no JS frameworks |
| II. Umbrella Bounded Contexts | Yes | PASS | Web layer only; reuses P2P domain context |
| III. OTP Process Architecture | No | N/A | No new processes |
| IV. Test-First Development | Yes | PASS | Tests for visibility, disabled states, events |
| V. Contracts and Behaviours | Yes | PASS | Reuses existing Handler behaviour via P2p.do_execute/3 |
| VI. Static Analysis | Yes | PASS | @spec on all new public functions, Credo/Dialyzer clean |
| VII. Lean LiveViews | Yes | PASS | Event handlers delegate to P2p.do_execute/3, components are function components |
| VIII. retro Design Fidelity | Yes | PASS | Uses retro menu patterns, disabled class, existing separator style |
| IX. Hot/Cold Data Separation | No | N/A | No new data storage |
| X. Scalable Architecture | No | N/A | UI feature, no architectural impact |
| XI. User-Facing Documentation | Yes | PASS | Help topic update for context menu P2P actions |

**Gate result**: PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/040-p2p-context-menus/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (minimal — no new entities)
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── events.md        # LiveView event contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── context_menu.ex          # MODIFY: add P2P items + viewer_is_identified attr
│   │   └── chat_context_menu.ex     # MODIFY: add P2P items to :nick variant + attrs
│   └── live/
│       └── chat_live/
│           ├── context_menu_events.ex  # MODIFY: add P2P event handlers + navigation
│           └── chat_live.html.heex     # MODIFY: pass viewer_is_identified + is_target_registered
└── test/
    └── retro_hex_chat_web/
        ├── components/
        │   ├── context_menu_test.exs          # NEW/MODIFY: P2P item visibility tests
        │   └── chat_context_menu_test.exs     # NEW/MODIFY: P2P item visibility tests
        └── live/
            └── chat_live/
                └── context_menu_events_test.exs  # MODIFY: P2P event handler tests

apps/retro_hex_chat/
└── lib/retro_hex_chat/
    └── chat/
        └── help_topics.ex           # MODIFY: update context menu help topic
```

**Structure Decision**: Existing umbrella structure. All changes are in the web layer (components + event handlers) with domain logic reuse from `RetroHexChat.P2P` via `P2p.do_execute/3`. One help topic update in the domain layer.

## Complexity Tracking

> No violations to justify — all gates passed.
