# Implementation Plan: Address Book

**Branch**: `003-address-book` | **Date**: 2026-02-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-address-book/spec.md`

## Summary

Implement a unified Address Book dialog (Alt+B) with four tabs — Contacts, Notify, Nick Colors, and Control — providing a single Windows 98-style interface for managing per-user relationships. Introduces two new domain concepts (ContactList, NickColors) with in-memory CRUD and async DB persistence following the established NotifyList pattern. The Notify tab reuses the existing NotifyList context; the Control tab shows a placeholder pending Cat F (Ignore System). Nick color overrides propagate to all nickname displays (chat, nicklist, whois, notify list, context menu). Context menu gains "Add to Contacts" and "Set Nick Color" quick actions.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
**Storage**: PostgreSQL 16+ (new `contacts` + `nick_color_overrides` tables) + in-memory Session state for guests
**Testing**: ExUnit (unit, integration, liveview, e2e tags), Floki for HTML assertions
**Target Platform**: Web (localhost:4000, Docker-ready)
**Project Type**: Phoenix umbrella (domain + web)
**Performance Goals**: Sub-second dialog open/tab switch, immediate nick color updates (no page refresh)
**Constraints**: Max 100 contacts, max 50 nick color overrides per user. In-memory for guests, persistent for registered users.
**Scale/Scope**: Per-user data, no cross-user queries. 2 new DB tables, 2 new domain modules, 1 new component, ~8 modified files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | Pure Elixir domain + LiveView UI, 98.css styling, PostgreSQL storage |
| II. Umbrella with Bounded Contexts | PASS | New modules in `Accounts` context (user-scoped data). No new bounded context. |
| III. OTP Process Architecture | PASS | No new GenServers needed — data is per-session, not per-channel. In-memory via Session struct. |
| IV. Test-First Development | PASS | Tests written before/alongside each module. Unit (domain CRUD), integration (persistence), liveview (dialog + events), e2e (full flows). |
| V. Contracts and Behaviours | PASS | No new "/" commands needed. Existing Handler behaviour pattern not affected. |
| VI. Static Analysis | PASS | All new public functions get `@spec`. Credo + Dialyxir + format enforced. |
| VII. Lean LiveViews | PASS | AddressBookDialog is a dedicated component. ChatLive delegates to domain contexts. Nick color resolution is a domain function. |
| VIII. Windows 98 Fidelity | PASS | Uses native 98.css `menu[role=tablist]` tab controls, sunken panels, 3D beveled borders. |
| IX. Hot/Cold Data Separation | PASS | Hot: Session-embedded maps. Cold: PostgreSQL via async Task.start writes. Follows NotifyList pattern exactly. |
| X. Scalable Architecture | PASS | Per-user data, no shared state. FK cascade deletes. Case-insensitive indexes for efficient lookups. |

**Post-Phase 1 re-check**: All gates remain PASS. No violations introduced by design decisions.

## Project Structure

### Documentation (this feature)

```text
specs/003-address-book/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: entity definitions
├── quickstart.md        # Phase 1: developer guide
├── contracts/
│   └── liveview-events.md  # Phase 1: event contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/                          # Domain layer
├── lib/retro_hex_chat/accounts/
│   ├── session.ex                            # MODIFY: add contacts + nick_colors fields
│   ├── contact.ex                            # NEW: Contact struct
│   ├── contact_list.ex                       # NEW: ContactList context (CRUD + persistence)
│   ├── contact_entry.ex                      # NEW: Ecto schema for contacts table
│   ├── nick_color.ex                         # NEW: NickColor struct
│   ├── nick_colors.ex                        # NEW: NickColors context (CRUD + persistence)
│   └── nick_color_entry.ex                   # NEW: Ecto schema for nick_color_overrides table
├── priv/repo/migrations/
│   └── TIMESTAMP_create_address_book_tables.exs  # NEW: migration
└── test/retro_hex_chat/accounts/
    ├── contact_test.exs                      # NEW: Contact struct tests
    ├── contact_list_test.exs                 # NEW: ContactList unit + integration tests
    ├── nick_color_test.exs                   # NEW: NickColor struct tests
    └── nick_colors_test.exs                  # NEW: NickColors unit + integration tests

apps/retro_hex_chat_web/                      # Web layer
├── lib/retro_hex_chat_web/
│   ├── live/chat_live.ex                     # MODIFY: assigns, events, nick_color_fn
│   └── components/
│       ├── address_book_dialog.ex            # NEW: tabbed dialog component
│       ├── context_menu.ex                   # MODIFY: add 2 new menu items
│       ├── toolbar.ex                        # MODIFY: add Address Book button
│       ├── menu_bar.ex                       # MODIFY: add Tools > Address Book
│       ├── chat_message.ex                   # MODIFY: use nick_color_fn assign
│       ├── nicklist.ex                       # MODIFY: use nick_color_fn assign
│       └── notify_list_window.ex             # MODIFY: use nick_color_fn assign
├── assets/js/
│   ├── app.js                                # MODIFY: register AddressBookHook
│   └── hooks/address_book_hook.js            # NEW: dblclick + interaction support
└── test/retro_hex_chat_web/live/
    └── address_book_test.exs                 # NEW: LiveView tests for all tabs
```

**Structure Decision**: Existing Phoenix umbrella structure. New domain modules placed in `Accounts` context (user-scoped personal data). Single new component for the dialog. No structural changes to the umbrella layout.

## Phased Implementation

### Phase 1: Domain Foundation (ContactList + NickColors)

**Goal**: Build the two new domain modules with full CRUD, validation, and persistence — mirroring the NotifyList pattern.

1. Migration: `create_address_book_tables` (contacts + nick_color_overrides)
2. Ecto schemas: `ContactEntry`, `NickColorEntry`
3. In-memory structs: `Contact`, `NickColor`
4. Context modules: `ContactList` (new/add/remove/update_note/sorted_entries/save/load), `NickColors` (new/add/remove/update_color/color_for/sorted_entries/save/load)
5. Session extension: add `contacts` and `nick_colors` fields with accessors
6. Full test coverage: struct tests, CRUD unit tests, persistence integration tests

**Dependencies**: None (pure domain, no web layer)

### Phase 2: Address Book Dialog Shell (US1)

**Goal**: Render the tabbed dialog with 98.css tab controls, Alt+B toggle, toolbar icon.

1. `AddressBookDialog` component with 4-tab layout using `menu[role=tablist]`
2. ChatLive assigns: `show_address_book`, `address_book_tab`
3. `window_keydown` handler for Alt+B
4. Toolbar button and menu bar "Tools > Address Book" item
5. Empty tab content (placeholder per tab)
6. LiveView tests for open/close/tab-switch

**Dependencies**: None beyond existing ChatLive

### Phase 3: Contacts Tab (US2)

**Goal**: Full CRUD for contacts within the Address Book dialog.

1. Contacts tab content: table with Nickname/Notes/First Contact Date columns
2. Add/Edit/Remove buttons with selection state
3. Add dialog (nickname + note fields), Edit dialog (note field)
4. ChatLive event handlers for contact CRUD
5. Session integration: `ContactList` ↔ `Session.contacts`
6. Persistence on identify (NickServ load/save)
7. LiveView tests for all CRUD operations

**Dependencies**: Phase 1 (ContactList), Phase 2 (dialog shell)

### Phase 4: Notify Tab (US3)

**Goal**: Render existing notify list data inside the Address Book as an alternate UI.

1. Notify tab content: reuse NotifyListWindow table layout + button pattern
2. Wire to existing notify list events (no new domain code)
3. Bidirectional sync: changes in Address Book reflect in standalone NotifyListWindow (already guaranteed since both read from `session.notify_list`)
4. LiveView tests for CRUD-via-Address-Book + sync verification

**Dependencies**: Phase 2 (dialog shell), existing NotifyList (feature 002)

### Phase 5: Nick Colors Tab + Override Integration (US4)

**Goal**: Full CRUD for nick color overrides, plus propagation to all nickname displays.

1. Nick Colors tab content: table with Nickname/Color columns, color swatch preview
2. Add dialog with nickname input + 16-color picker grid
3. Edit dialog with color picker only
4. `NickColors.color_for/2` domain function: check overrides, return hex or nil
5. `nick_color_fn` assign in ChatLive: `fn nick -> NickColors.color_for(...) || hash_color(nick) end`
6. Propagate `nick_color_fn` to: ChatMessage, Nicklist, NotifyListWindow, ContextMenu, AddressBookDialog
7. Session integration + persistence on identify
8. LiveView tests for CRUD + color override rendering verification

**Dependencies**: Phase 1 (NickColors), Phase 2 (dialog shell)

### Phase 6: Context Menu Integration (FR-025, FR-026)

**Goal**: Add "Add to Contacts" and "Set Nick Color" to the nick right-click context menu.

1. ContextMenu component: add two new items (after Whois, before operator separator)
2. "Add to Contacts" handler: direct add using `context_menu.target_nick`
3. "Set Nick Color" handler: show inline color picker dropdown at menu position
4. `context_pick_color` handler: add/update override and close
5. LiveView tests for both context menu actions

**Dependencies**: Phase 1 (both domain modules), Phase 5 (nick_color_fn wiring)

### Phase 7: Control Tab Placeholder (US5)

**Goal**: Render placeholder message for the Control tab.

1. Static content: "Ignore management will be available in a future update."
2. LiveView test asserting placeholder text

**Dependencies**: Phase 2 (dialog shell)

### Phase 8: Polish, E2E Tests, data-testid Attributes

**Goal**: End-to-end testing, accessibility attributes, final integration verification.

1. Add `data-testid` attributes to all new interactive elements
2. E2E tests covering all 5 user stories
3. Cross-tab sync verification (Notify tab ↔ standalone window)
4. Nick color override verification across all display locations
5. Persistence round-trip tests (identify → add data → disconnect → reconnect → verify)
6. Linter + dialyzer + format cleanup

**Dependencies**: All previous phases

## Complexity Tracking

> No constitution violations. No entries needed.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| *(none)*  | —          | —                                    |
