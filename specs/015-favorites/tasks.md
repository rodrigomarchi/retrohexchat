# Tasks: Favorites / Bookmarks

**Input**: Design documents from `/specs/015-favorites/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/favorites.md, quickstart.md

**Tests**: Included per project constitution (TDD approach).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration, domain structs, encryption utility, and Session integration

- [X] T001 Create favorites database migration in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDD_create_favorites.exs`
- [X] T002 Create FavoriteEntry struct in `apps/retro_hex_chat/lib/retro_hex_chat/chat/favorite_entry.ex`
- [X] T003 [P] Create FavoriteEntry Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/favorite_entry.ex`
- [X] T004 [P] Create PasswordEncryption module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/password_encryption.ex`
- [X] T005 [P] Write PasswordEncryption tests in `apps/retro_hex_chat/test/retro_hex_chat/chat/password_encryption_test.exs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Favorites domain module, Session integration, and domain tests — MUST be complete before ANY user story UI work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Create Favorites domain module with CRUD operations (new, entries, add_entry, update_entry, remove_entry, find_entry, has_entry?, move_up, move_down, auto_join_entries) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/favorites.ex`
- [X] T007 Add save/load persistence functions to Favorites module (delete-all-then-reinsert pattern per AutoJoinList) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/favorites.ex`
- [X] T008 Add `favorites` field to Session struct with getter/setter (get_favorites/set_favorites) and integrate into `load_persisted_data` chain in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [X] T009 Write Favorites domain tests (CRUD, reordering, duplicates, persistence save/load) in `apps/retro_hex_chat/test/retro_hex_chat/chat/favorites_test.exs`

**Checkpoint**: Foundation ready — Favorites domain module and Session integration complete, all domain tests pass

---

## Phase 3: User Story 1 — Add and Use Favorites (Priority: P1) 🎯 MVP

**Goal**: Users can add channels to favorites via treebar context menu and join/switch channels via the Favorites menu in the menu bar

**Independent Test**: Right-click a channel in treebar → "Add to Favorites" → fill dialog → save → verify channel appears in Favorites menu → click it to join/switch

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T010 [P] [US1] Write treebar context menu and Add Favorite dialog LiveView tests in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/favorites_test.exs`

### Implementation for User Story 1

- [X] T011 [P] [US1] Create TreebarContextMenu component (phx-contextmenu on channel items, "Add to Favorites" option) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar_context_menu.ex`
- [X] T012 [P] [US1] Create FavoriteDialog component (Add/Edit mode, channel name, description, masked password, auto-join checkbox) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/favorite_dialog.ex`
- [X] T013 [US1] Add `phx-contextmenu` event to treebar channel items and render TreebarContextMenu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex`
- [X] T014 [US1] Add "Favorites" top-level menu to MenuBar with dynamic favorites list, checkmarks for joined channels, and "Organize Favorites..." / "Add to Favorites" items in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex`
- [X] T015 [US1] Add socket assigns (favorites-related: show_favorite_dialog, favorite_dialog_mode, favorite_dialog_channel, favorite_dialog_data, treebar_context_menu) and event handlers (channel_right_click, close_treebar_context_menu, add_to_favorites, save_favorite, close_favorite_dialog, join_favorite) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T016 [US1] Add treebar context menu CSS styles (absolute positioning, z-index) in `apps/retro_hex_chat_web/assets/css/layout.css` (if needed beyond retro design system defaults)

**Checkpoint**: User Story 1 fully functional — users can add favorites and join/switch channels via the Favorites menu

---

## Phase 4: User Story 2 — Organize Favorites (Priority: P2)

**Goal**: Users can reorder, edit, and remove favorites via the Organize Favorites dialog

**Independent Test**: Add multiple favorites → open Organize Favorites → reorder with Up/Down → edit a favorite → remove a favorite → verify Favorites menu reflects all changes

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T017 [P] [US2] Write Organize Favorites dialog LiveView tests (list display, reorder, edit, remove) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/organize_favorites_test.exs`

### Implementation for User Story 2

- [X] T018 [US2] Create OrganizeFavoritesDialog component (ordered list, selection state, Up/Down/Edit/Remove buttons, "Password set" indicator) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/organize_favorites_dialog.ex`
- [X] T019 [US2] Add socket assigns (show_organize_favorites, organize_favorites_selected) and event handlers (open_organize_favorites, close_organize_favorites, favorite_select, favorite_move_up, favorite_move_down, favorite_edit, favorite_remove) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: User Stories 1 AND 2 both work independently — full favorites lifecycle (add, use, organize)

---

## Phase 5: User Story 3 — Auto-Join Favorites on Connect (Priority: P3)

**Goal**: Favorites marked "auto-join" are automatically joined when the user connects

**Independent Test**: Create favorites with auto-join enabled and disabled → reconnect → verify only auto-join favorites are joined in order

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T020 [P] [US3] Write auto-join favorites tests (auto-join enabled/disabled, password channels, join order) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/favorites_autojoin_test.exs`

### Implementation for User Story 3

- [X] T021 [US3] Add auto-join logic that fires after existing perform/autojoin system completes — iterate `Favorites.auto_join_entries/1` and call `join_channel` for each in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: All core user stories functional — favorites auto-join on connect works alongside existing perform system

---

## Phase 6: User Story 4 — Duplicate and Update Handling (Priority: P4)

**Goal**: System detects duplicate favorites and offers to update instead of creating duplicates

**Independent Test**: Add #elixir to favorites → try to add #elixir again → verify edit dialog opens with existing data and a notice

### Implementation for User Story 4

- [X] T022 [US4] Update `add_to_favorites` event handler to check `Favorites.has_entry?/2` and open dialog in edit mode with notice when duplicate detected in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: All user stories complete — duplicate detection prevents data inconsistency

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, edge case handling, and full validation

- [X] T023 [P] Add Favorites and Organize Favorites help topics to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [X] T024 [P] Handle edge cases: empty favorites menu ("No favorites" disabled item), Up/Down button boundary disabling, join failure messages (wrong key, banned) in relevant components and handlers
- [X] T025 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Stories (Phase 3–6)**: All depend on Phase 2 completion
  - US1 (P1): Can start after Phase 2
  - US2 (P2): Can start after Phase 2, but practically depends on US1 for dialog reuse
  - US3 (P3): Can start after Phase 2, independent of US1/US2
  - US4 (P4): Depends on US1 (needs add_to_favorites handler to exist)
- **Polish (Phase 7)**: Depends on all user stories being complete

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Components before LiveView integration
- Domain logic before UI handlers
- Core implementation before edge case handling

### Parallel Opportunities

**Phase 1**:
- T002 (struct) can start immediately
- T003 (schema) and T004 (encryption) and T005 (encryption tests) can run in parallel after T002

**Phase 2**:
- T006 → T007 → T008 → T009 (sequential — each builds on prior)

**Phase 3 (US1)**:
- T010 (tests), T011 (context menu component), T012 (dialog component) can run in parallel
- T013, T014, T015 depend on T011/T012 completion

**Phase 4–6**:
- Recommended sequential execution (P1 → P2 → P3 → P4) for a single developer

**Phase 7**:
- T023 and T024 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch tests and components together:
Task: "Write favorites LiveView tests in apps/retro_hex_chat_web/test/.../favorites_test.exs"
Task: "Create TreebarContextMenu component in apps/retro_hex_chat_web/.../treebar_context_menu.ex"
Task: "Create FavoriteDialog component in apps/retro_hex_chat_web/.../favorite_dialog.ex"

# Then sequentially:
Task: "Add phx-contextmenu to treebar in apps/retro_hex_chat_web/.../treebar.ex"
Task: "Add Favorites menu to menu_bar.ex"
Task: "Add assigns and handlers to chat_live.ex"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration, structs, encryption)
2. Complete Phase 2: Foundational (Favorites module, Session integration)
3. Complete Phase 3: User Story 1 (add favorites, Favorites menu, join/switch)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → MVP ready
3. Add User Story 2 → Organize dialog → Full management
4. Add User Story 3 → Auto-join on connect → Automation
5. Add User Story 4 → Duplicate handling → Polish
6. Complete Phase 7 → Help docs, edge cases, CI validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Favorites auto-join is independent of existing Perform auto-join system (feature 009)
- Password encryption uses Plug.Crypto.MessageEncryptor (no new deps)
- Follows AutoJoinList multi-row persistence pattern (delete-all-then-reinsert)
