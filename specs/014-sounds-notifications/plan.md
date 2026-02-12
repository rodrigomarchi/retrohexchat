# Implementation Plan: Sounds & Notifications

**Branch**: `014-sounds-notifications` | **Date**: 2026-02-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-sounds-notifications/spec.md`

## Summary

Implement a comprehensive notification system with four pillars: (1) per-event sound configuration with a catalog of 14+ synthesized sounds and a Windows 98-styled dialog with OK/Cancel/Apply, (2) global mute toggle in the status bar persisted via localStorage, (3) visual activity indicators (treebar flash via CSS animation + browser title bar alternation via JS hook), and (4) PM typing indicators broadcast over PubSub with 5-second timeout. Sound preferences persist in PostgreSQL (JSONB) for registered users, in-memory for guests.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
**Storage**: PostgreSQL 16+ (1 new table: `sound_settings` with JSONB columns) + in-memory Session state for guests + localStorage for mute state
**Testing**: ExUnit (unit, integration, liveview, e2e tags), Mox, Floki
**Target Platform**: Web (modern browsers with Web Audio API support)
**Project Type**: Umbrella (existing)
**Performance Goals**: Sound playback <100ms from event, typing indicator <2s latency, title flash <2s from event
**Constraints**: No audio file bundling (programmatic synthesis), no JS UI frameworks, LiveView-only UI
**Scale/Scope**: 10 event types, 14+ sound catalog entries, 1 new DB table, ~10 modified files, ~8 new files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | All server logic in Elixir/Phoenix. JS limited to hooks (sound playback, title flash, typing debounce) — same pattern as existing SoundHook, KeyboardHook |
| II. Umbrella with Bounded Contexts | PASS | Domain module (`SoundSettings`) in `retro_hex_chat` app under `Chat` context. Web components in `retro_hex_chat_web`. No cross-context bleeding |
| III. OTP Process Architecture | PASS | No new GenServers needed. Typing uses PubSub (existing). Sound settings are per-session state. Title flash is client-side only |
| IV. Test-First Development | PASS | Unit tests for SoundSettings domain module, LiveView tests for dialog/typing/flash, E2E tests for end-to-end flows |
| V. Contracts and Behaviours | PASS | SoundSettings follows existing settings module pattern (new/get/set/save/load). All public functions have @spec |
| VI. Static Analysis | PASS | @spec on all public functions. Credo/Dialyzer/format enforced |
| VII. Lean LiveViews | PASS | Dialog is a function component. LiveView delegates to SoundSettings domain module. JS hooks minimal and isolated (sound, title flash, typing debounce) |
| VIII. Windows 98 Design Fidelity | PASS | Dialog uses 98.css window/fieldset/button. OK/Cancel/Apply button pattern. Mute icon in status bar. Treebar flash uses existing retro-styled CSS animation |
| IX. Hot/Cold Data Separation | PASS | Sound settings in PostgreSQL (cold). Mute state in localStorage (client). Typing state transient in socket assigns (hot). No ETS needed |
| X. Scalable Architecture | PASS | PubSub-based typing works across nodes. No single-point bottlenecks. JSONB allows easy schema evolution |
| XI. User-Facing Documentation | PASS | Help topics for: Sounds configuration, Mute, Visual notifications, Typing indicator. Cross-references to related topics |

**Gate result**: ALL PASS — no violations, no complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/014-sounds-notifications/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: technology decisions
├── data-model.md        # Phase 1: entity definitions
├── quickstart.md        # Phase 1: implementation guide
├── contracts/           # Phase 1: API contracts
│   └── sound_settings.md
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── accounts/
│   │   └── session.ex                          # MODIFY: add sound_settings field
│   └── chat/
│       ├── sound_settings.ex                   # NEW: domain module
│       ├── help_topics.ex                      # MODIFY: add help topics
│       └── schemas/
│           └── sound_setting.ex                # NEW: Ecto schema
├── priv/repo/migrations/
│   └── YYYYMMDD_create_sound_settings.exs      # NEW: migration
└── test/retro_hex_chat/
    └── chat/
        └── sound_settings_test.exs             # NEW: unit tests

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── chat_live.ex                        # MODIFY: dialog, typing, sound dispatch, flash
│   └── components/
│       ├── sound_settings_dialog.ex            # NEW: dialog component
│       ├── menu_bar.ex                         # MODIFY: add Sounds menu item
│       ├── status_bar.ex                       # MODIFY: add mute toggle
│       └── treebar.ex                          # MODIFY: flash_channels support
├── assets/
│   ├── js/
│   │   ├── app.js                              # MODIFY: register TitleFlashHook
│   │   └── hooks/
│   │       ├── sound_hook.js                   # MODIFY: expand catalog, named sounds
│   │       └── title_flash_hook.js             # NEW: title bar alternation
│   └── css/
│       └── layout.css                          # MODIFY: typing indicator, mute icon styles
└── test/retro_hex_chat_web/live/
    ├── sound_settings_test.exs                 # NEW: dialog tests
    ├── typing_indicator_test.exs               # NEW: typing tests
    └── visual_notifications_test.exs           # NEW: flash/title tests
```

**Structure Decision**: Follows the existing umbrella structure. Domain logic (`SoundSettings`) in `retro_hex_chat` app under `Chat` bounded context. UI components and LiveView handlers in `retro_hex_chat_web`. Two new JS hooks (`TitleFlashHook` for title bar, expanded `SoundHook` for catalog). Single PostgreSQL table with JSONB columns.
