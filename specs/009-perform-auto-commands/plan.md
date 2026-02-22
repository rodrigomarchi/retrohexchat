# Implementation Plan: Perform / Auto-Commands

**Branch**: `009-perform-auto-commands` | **Date**: 2026-02-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-perform-auto-commands/spec.md`

## Summary

Implement mIRC-style Perform (auto-execute commands on connect), auto-join channel list, and auto-reconnect with exponential backoff. The feature uses a two-tier storage model: in-memory Session state for runtime + PostgreSQL for registered user persistence + browser localStorage for reconnection state. Sequential command execution uses OTP's `Process.send_after` pattern. Auto-reconnect leverages Phoenix LiveView's built-in WebSocket reconnection with a custom JS overlay for user feedback.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (3 new tables: `perform_entries`, `autojoin_entries`, `perform_settings`) + in-memory Session state for guests + browser localStorage for reconnection
**Testing**: ExUnit with `@tag :unit`, `@tag :integration`, `@tag :liveview`, `@tag :e2e`
**Target Platform**: Web (desktop browsers)
**Project Type**: Phoenix umbrella (retro_hex_chat domain + retro_hex_chat_web)
**Performance Goals**: Perform command list executes within 5 seconds of connection (100ms between commands, up to 50 commands = 5s max)
**Constraints**: Auto-reconnect overlay must be pure JS/CSS (LiveView unavailable during disconnection)
**Scale/Scope**: Max 50 perform commands + 20 auto-join channels per user

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive Stack | Yes | PASS | All server logic in Elixir/Phoenix. ReconnectHook JS is minimal and isolated. |
| II. Umbrella with Bounded Contexts | Yes | PASS | Domain structs/CRUD in `Chat` context (following IgnoreList/HighlightWords pattern). Handlers in `Commands`. Web layer in `retro_hex_chat_web`. |
| III. OTP Process Architecture | Yes | PASS | Sequential execution via `Process.send_after` chain. No new GenServers needed (perform data lives in Session). |
| IV. Test-First Development | Yes | PASS | Unit tests for structs/CRUD, integration for DB persistence, LiveView tests for execution flow, E2E for user journeys. |
| V. Contracts and Behaviours | Yes | PASS | `/perform` and `/autojoin` implement `Handler` behaviour. Ecto schemas with changesets. |
| VI. Static Analysis from Day One | Yes | PASS | `@spec` on all public functions. Credo strict. Dialyzer clean. |
| VII. Lean LiveViews & Components | Yes | PASS | ChatLive delegates to PerformList/AutoJoinList CRUD. PerformDialog is a function component. |
| VIII. retro Design Fidelity | Yes | PASS | PerformDialog uses retro design system (window, title-bar, sunken-panel). Reconnect overlay styled as retro dialog. |
| IX. Hot/Cold Data Separation | Yes | PASS | Hot: Session struct (in-memory). Cold: PostgreSQL (3 tables). localStorage for reconnection bridge. |
| X. Scalable Architecture | Yes | PASS | Per-user data, no shared state. PubSub patterns unchanged. |
| XI. User-Facing Documentation | Yes | PASS | Help topics for `/perform`, `/autojoin`, Perform feature, Auto-reconnect. Keyboard shortcuts updated. |

## Project Structure

### Documentation (this feature)

```text
specs/009-perform-auto-commands/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0: Architecture decisions
├── data-model.md        # Phase 1: Entity definitions
├── quickstart.md        # Phase 1: Implementation guide
├── contracts/
│   ├── domain.md        # Phase 1: Domain module contracts
│   └── web.md           # Phase 1: Web layer contracts
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                              # Domain layer
├── lib/retro_hex_chat/
│   ├── accounts/
│   │   └── session.ex                            # MODIFIED: +perform_list, +autojoin_list fields
│   ├── chat/
│   │   ├── perform_entry.ex                      # NEW: PerformEntry struct
│   │   ├── perform_list.ex                       # NEW: PerformList CRUD + mask + persistence
│   │   ├── autojoin_entry.ex                     # NEW: AutoJoinEntry struct
│   │   ├── autojoin_list.ex                      # NEW: AutoJoinList CRUD + persistence
│   │   ├── schemas/
│   │   │   ├── perform_list_entry.ex             # NEW: Ecto schema
│   │   │   ├── autojoin_list_entry.ex            # NEW: Ecto schema
│   │   │   └── perform_settings.ex               # NEW: Ecto schema (PK=nickname)
│   │   └── help_topics.ex                        # MODIFIED: +4 help topics
│   └── commands/
│       ├── registry.ex                           # MODIFIED: +perform, +autojoin handlers
│       └── handlers/
│           ├── perform.ex                        # NEW: /perform handler
│           └── autojoin.ex                       # NEW: /autojoin handler
├── priv/repo/migrations/
│   ├── *_create_perform_entries.exs              # NEW: perform_entries + perform_settings
│   └── *_create_autojoin_entries.exs             # NEW: autojoin_entries
└── test/
    ├── retro_hex_chat/chat/
    │   ├── perform_entry_test.exs                # NEW
    │   ├── perform_list_test.exs                 # NEW
    │   ├── autojoin_entry_test.exs               # NEW
    │   └── autojoin_list_test.exs                # NEW
    └── retro_hex_chat/commands/handlers/
        ├── perform_test.exs                      # NEW
        └── autojoin_test.exs                     # NEW

apps/retro_hex_chat_web/                          # Web layer
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── chat_live.ex                          # MODIFIED: perform execution, dialog events,
│   │                                             #   reconnect state, Alt+P, restore_session
│   └── components/
│       ├── perform_dialog.ex                     # NEW: retro dialog (2 tabs)
│       └── menu_bar.ex                           # MODIFIED: +Perform menu item
├── assets/
│   ├── js/
│   │   ├── app.js                                # MODIFIED: +ReconnectHook, +reconnectAfterMs
│   │   └── hooks/
│   │       └── reconnect_hook.js                 # NEW: disconnect overlay, localStorage, cancel
│   └── css/
│       ├── layout.css                            # MODIFIED: +reconnect overlay styles
│       └── dark-theme.css                        # MODIFIED: +dark theme counterparts
└── test/
    ├── retro_hex_chat_web/live/
    │   ├── chat_live_perform_test.exs             # NEW: perform execution tests
    │   └── chat_live_perform_dialog_test.exs      # NEW: dialog interaction tests
    ├── retro_hex_chat_web/components/
    │   └── perform_dialog_test.exs                # NEW: component tests
    └── e2e/
        └── perform_e2e_test.exs                   # NEW: E2E tests
```

**Structure Decision**: Follows existing umbrella structure. Domain structs and CRUD in `Chat` context (same as IgnoreList, HighlightWords). Command handlers in `Commands.Handlers`. Web components follow existing dialog pattern.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| ReconnectHook JS beyond "minimal hooks" (Principle VII) | Auto-reconnect overlay CANNOT use LiveView — it is disconnected. Pure JS/CSS overlay is architecturally mandatory. | No simpler alternative exists; LiveView's built-in reconnection has no UI customization API. The hook remains isolated (single file, single responsibility). |
| localStorage for session state (not in constitution) | Reconnection requires knowing the previous session state. In-memory Session dies with the LiveView process. DB requires identification. localStorage bridges the gap. | Server-side session storage would require a separate GenServer/ETS table surviving LiveView process death — more complex and still needs a client-side identifier. |

## Implementation Phases

### Phase 1: Domain Structs & CRUD (Pure Elixir, No DB)

**Goal**: In-memory PerformList and AutoJoinList with full test coverage.

**New files**:
- `chat/perform_entry.ex` — Struct with `new/1`
- `chat/perform_list.ex` — CRUD: new, add, remove, move, clear, entries, count, full?, enabled?, set_enabled, mask_command, disallowed_command?, valid_command?
- `chat/autojoin_entry.ex` — Struct with `new/1`
- `chat/autojoin_list.ex` — CRUD: new, add, remove, update, clear, entries, count, full?
- `accounts/session.ex` — Add `perform_list` and `autojoin_list` fields with getters/setters

**Key design**:
- `PerformList` internal structure: `%{entries: [PerformEntry.t()], settings: %{enable_on_connect: true}}`
- `AutoJoinList` internal structure: `%{entries: [AutoJoinEntry.t()]}`
- `mask_command/1` regex: replaces password after `identify` in `/ns identify` and `/msg NickServ identify` patterns
- Disallowed commands: `/quit`, `/perform`, `/autojoin`, `/disconnect`
- Max entries: 50 perform, 20 autojoin

**Tests**: Unit tests for all CRUD operations, validation, masking, edge cases.

---

### Phase 2: Persistence (Migrations + Ecto + Save/Load)

**Goal**: Database persistence for registered users.

**New files**:
- Migration: `create_perform_entries` — `perform_entries` table + `perform_settings` table
- Migration: `create_autojoin_entries` — `autojoin_entries` table
- `chat/schemas/perform_list_entry.ex` — Ecto schema
- `chat/schemas/autojoin_list_entry.ex` — Ecto schema
- `chat/schemas/perform_settings.ex` — Ecto schema (PK = owner_nickname)

**Modified files**:
- `chat/perform_list.ex` — Add `save/2`, `load/1`
- `chat/autojoin_list.ex` — Add `save/2`, `load/1`

**Migration patterns** (following existing):
- FK to `registered_nicks(nickname)` with `on_delete: :delete_all`
- `timestamps(type: :utc_datetime_usec)`
- Case-insensitive unique indexes using `lower()` expressions
- CHECK constraints for data validation

**Tests**: Integration tests for save/load round-trips.

---

### Phase 3: Command Handlers

**Goal**: `/perform` and `/autojoin` slash commands.

**New files**:
- `commands/handlers/perform.ex` — Handler with subcommands: add, remove, move, clear, bare
- `commands/handlers/autojoin.ex` — Handler with subcommands: add, remove, clear, bare

**Modified files**:
- `commands/registry.ex` — Add `"perform" => Handlers.Perform`, `"autojoin" => Handlers.AutoJoin`
- `chat_live.ex` — Add `handle_ui_action` clauses: `:open_perform_dialog`, `:perform_add`, `:perform_remove`, `:perform_move`, `:perform_clear`, `:perform_list_display`, `:autojoin_add`, `:autojoin_remove`, `:autojoin_clear`, `:autojoin_list_display`
- `chat_live.ex` — Add `maybe_persist_perform_list/2`, `maybe_persist_autojoin_list/2` helpers
- `chat_live.ex` — Extend `load_persisted_data/2` with PerformList.load and AutoJoinList.load

**Handler result patterns**: All subcommands return `{:ok, :ui_action, action_atom, payload}` — ChatLive's `handle_ui_action` does the actual CRUD and persistence.

**Tests**: Unit tests for handler validate/execute. LiveView tests for UI action handling.

---

### Phase 4: Perform Execution on Connect

**Goal**: Auto-execute perform commands and auto-join channels on connection.

**Modified files**:
- `chat_live.ex` — mount: trigger perform execution after initial setup
- `chat_live.ex` — `handle_info({:execute_perform, index})`: parse command via `Parser.parse/1`, dispatch via `dispatch_command/4`, schedule next with `Process.send_after(self(), {:execute_perform, index + 1}, 100)`
- `chat_live.ex` — `handle_info({:execute_autojoin, index})`: call `join_channel/4` for each auto-join entry, schedule next
- `chat_live.ex` — System messages: "* Performing: /ns identify ****..." and "* Auto-joining #elixir..."
- `chat_live.ex` — `push_event("save_reconnect_state", state)` on significant changes (join, part, perform/autojoin modification)

**Execution flow**:
1. Mount completes (join #lobby, subscribe PubSub)
2. Check if perform list has entries and is enabled
3. `send(self(), {:execute_perform, 0})`
4. Each perform command executes, then schedules next after 100ms
5. After last perform: `send(self(), {:execute_autojoin, 0})`
6. After last autojoin: execution complete

**Tests**: LiveView tests for sequential execution, error isolation, system messages.

---

### Phase 5: Perform Dialog UI

**Goal**: retro dialog for visual perform/autojoin management.

**New files**:
- `components/perform_dialog.ex` — Two-tab dialog (Commands, Auto-Join)

**Modified files**:
- `chat_live.ex` — Dialog event handlers (open, close, tab switch, CRUD, move up/down)
- `chat_live.ex` — `window_keydown` handler for Alt+P
- `chat_live.ex` — `assign_defaults/2` for dialog state assigns
- `components/menu_bar.ex` — Add "Perform" item under Tools menu
- `css/layout.css` — Dialog styles (if needed beyond retro design system)
- `css/dark-theme.css` — Dark theme counterparts

**Dialog structure**:
- Tab 1 "Commands": Listbox (masked passwords), Add/Edit/Remove/Move Up/Move Down buttons, "Enable on connect" checkbox
- Tab 2 "Auto-Join": Listbox (channel + key), Add/Edit/Remove buttons
- Sub-dialogs: Add Command (text input), Edit Command (text input with unmasked value), Add Channel (channel + key inputs), Edit Channel (channel + key inputs)

**Tests**: Component tests for rendering. LiveView tests for interactions.

---

### Phase 6: Auto-Reconnect (JS)

**Goal**: Client-side reconnection overlay with exponential backoff.

**New files**:
- `assets/js/hooks/reconnect_hook.js` — Disconnect detection, overlay UI, countdown timer, cancel button, localStorage management

**Modified files**:
- `assets/js/app.js` — Register ReconnectHook, customize `reconnectAfterMs`
- `chat_live.ex` — `push_event("intentional_disconnect")` in quit/disconnect handlers
- `chat_live.ex` — `push_event("save_reconnect_state", state)` on state changes
- `css/layout.css` — Reconnect overlay styles (retro themed window)
- `css/dark-theme.css` — Dark theme overlay styles

**ReconnectHook behavior**:
1. `mounted()`: Check for saved state, observe LiveView root for `phx-disconnected` class
2. On disconnect: If not intentional → show overlay with countdown, attempt counter
3. Countdown updates every second, backoff: 1s, 2s, 4s, 8s, 16s, 30s cap
4. Cancel button: remove overlay, clear saved state, redirect to `/`
5. On reconnect: hide overlay, push `restore_session` event with saved state
6. Max 10 attempts: show "Reconnection failed" with "Return to Connect" button

**Tests**: E2E tests for intentional disconnect not triggering reconnect.

---

### Phase 7: Session Restoration on Reconnect

**Goal**: Restore previous session state after auto-reconnect.

**Modified files**:
- `chat_live.ex` — `handle_event("restore_session", params)`: detect reconnect, load state
- `chat_live.ex` — `handle_info({:execute_rejoin, index})`: rejoin previous channels with deduplication
- `chat_live.ex` — Active tab restoration: set `active_channel` from saved state
- `chat_live.ex` — Nickname conflict detection: check if nickname is already in use

**Rejoin deduplication**:
- Build a set of channels already joined (from perform + autojoin)
- Only rejoin channels from previous session that aren't already joined
- Skip #lobby (always auto-joined by mount)

**Tests**: LiveView tests for reconnect flow, deduplication, conflict detection.

---

### Phase 8: Help Topics & E2E Tests

**Goal**: Documentation and comprehensive end-to-end testing.

**Modified files**:
- `chat/help_topics.ex` — Add topics:
  - `cmd-perform`: `/perform` command syntax and examples
  - `cmd-autojoin`: `/autojoin` command syntax and examples
  - `feature-perform`: Perform dialog and auto-execute feature
  - `feature-auto-reconnect`: Auto-reconnect behavior and settings
  - Update `keyboard-shortcuts` topic with Alt+P
  - Update cross-references in related topics

**New test files**:
- `e2e/perform_e2e_test.exs` — Full user journeys

**E2E scenarios**:
- Add perform commands via dialog and verify list
- Add auto-join channels via command and verify list
- Connect and verify perform execution with system messages
- `/quit` does not trigger reconnect overlay
- Dialog CRUD (add, edit, remove, move up/down)
- Password masking in dialog and command output
- Enable/disable toggle
- Tab switching in dialog

**Tests**: E2E tests, help topic unit tests.
