# Implementation Plan: Flood Protection

**Branch**: `013-flood-protection` | **Date**: 2026-02-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/013-flood-protection/spec.md`

## Summary

Add per-user flood protection to RetroHexChat with four capabilities: (1) anti-spam duplicate message detection that blocks repeated identical messages from the same sender to the same target, (2) auto-ignore that automatically adds flooding users to the receiver's ignore list for a configurable duration, (3) CTCP reply flood protection that limits outgoing CTCP replies per time window, and (4) a settings dialog for user-configurable thresholds with DB persistence for registered users.

The feature follows the receiver-side filtering pattern established by the ignore system — flood detection runs in each user's LiveView process using in-memory trackers (socket assigns), while settings persist via the same schema/domain-module/session pattern used by CTCP settings and ignore list.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (1 new table: `flood_protection_settings`) + in-memory socket assigns for trackers
**Testing**: ExUnit with Mox, ExMachina, StreamData, Floki; `@tag :unit`, `@tag :integration`, `@tag :liveview`
**Target Platform**: Web (server-rendered via LiveView)
**Project Type**: Umbrella (retro_hex_chat domain + retro_hex_chat_web)
**Performance Goals**: Flood detection must add <1ms latency per incoming message; auto-ignore activates within 1 second of threshold; auto-expire within 5 seconds of timer
**Constraints**: Max 50 tracked senders per user; trackers reset on disconnect; in-memory only (no DB writes for tracking state)
**Scale/Scope**: Per-user feature, no server-wide state changes. 1 new DB table, 1 new domain module, 1 new schema, 1 new dialog component, Session struct extension, ChatLive integration, help topics.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive Stack | PASS | Elixir/Phoenix/LiveView/PostgreSQL/retro CSS framework only |
| II. Umbrella App with Bounded Contexts | PASS | Domain logic in `RetroHexChat.Chat` context (FloodProtection module). Web layer in `RetroHexChatWeb`. Trackers live in socket assigns (LiveView state), consistent with how CTCP rate limiting is already tracked. |
| III. OTP Process Architecture | PASS | No new GenServers needed — flood tracking is per-LiveView-process state (socket assigns), consistent with existing CTCP rate limiting pattern. Auto-ignore timers use `Process.send_after` (same pattern as existing ignore timers). |
| IV. Test-First Development | PASS | Unit tests for FloodProtection domain module, FloodTracker, DuplicateTracker. Integration tests for DB persistence. LiveView tests for dialog and message filtering. |
| V. Contracts and Behaviours | PASS | FloodProtection module follows the established settings pattern (new/load/save). No new commands, so no new Handler modules needed. |
| VI. Static Analysis | PASS | @spec on all public functions. Credo/Dialyxir compliance. |
| VII. Lean LiveViews & Component Architecture | PASS | All flood logic delegated to domain modules (FloodProtection, FloodTracker, DuplicateTracker). LiveView only calls domain functions and manages assigns. Dialog is a separate function component. |
| VIII. retro Design Fidelity | PASS | Settings dialog follows retro design patterns (window, title-bar, fieldsets, buttons) matching existing CTCP/Ignore dialogs. |
| IX. Hot/Cold Data Separation | PASS | Trackers (hot) in socket assigns. Settings (cold, user config) in PostgreSQL. Clean separation. |
| X. Scalable Architecture | PASS | Per-process state scales naturally with LiveView processes. No shared mutable state. DB table uses owner_nickname primary key referencing registered_nicks. |
| XI. User-Facing Documentation | PASS | Help topic for flood protection feature. Cross-references to ignore list, CTCP. |

**Gate result**: ALL PASS. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/013-flood-protection/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: research findings
├── data-model.md        # Phase 1: data model
├── quickstart.md        # Phase 1: quickstart guide
├── contracts/           # Phase 1: internal contracts
│   └── flood-protection-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── chat/
│   │   ├── flood_protection.ex          # Domain: settings CRUD + save/load
│   │   ├── flood_tracker.ex             # Domain: per-sender message count tracking
│   │   ├── duplicate_tracker.ex         # Domain: per-sender-target duplicate detection
│   │   └── schemas/
│   │       └── flood_protection_setting.ex  # Ecto schema for DB persistence
│   └── accounts/
│       └── session.ex                   # Extended with flood_protection field
├── priv/repo/migrations/
│   └── YYYYMMDDHHMMSS_create_flood_protection_settings.exs
└── test/
    ├── retro_hex_chat/chat/
    │   ├── flood_protection_test.exs    # Unit: settings CRUD
    │   ├── flood_tracker_test.exs       # Unit: flood detection logic
    │   └── duplicate_tracker_test.exs   # Unit: duplicate detection logic
    └── retro_hex_chat/chat/schemas/
        └── flood_protection_setting_test.exs  # Integration: DB persistence

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── flood_protection_dialog.ex   # retro-styled settings dialog
│   └── live/
│       └── chat_live.ex                 # Extended: handle_info filtering, dialog events
└── test/
    └── retro_hex_chat_web/live/
        └── chat_live_flood_test.exs     # LiveView: dialog + message filtering
```

**Structure Decision**: Follows the existing umbrella structure. Domain logic (FloodProtection, FloodTracker, DuplicateTracker) in `retro_hex_chat` app under the `Chat` bounded context. Web layer (dialog component, ChatLive integration) in `retro_hex_chat_web`. This matches the exact patterns used by the CTCP settings and ignore list features.

## Complexity Tracking

> No constitution violations. Table intentionally left empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    | —          | —                                   |
