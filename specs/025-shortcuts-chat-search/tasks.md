# Tasks: Keyboard Shortcuts & Chat Search

**Input**: Design documents from `/specs/025-shortcuts-chat-search/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/events.md

**Tests**: Included — TDD is non-negotiable per Constitution Principle IV.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain app**: `apps/retro_hex_chat/lib/retro_hex_chat/`
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web app**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **Web tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`
- **JS hooks**: `apps/retro_hex_chat_web/assets/js/hooks/`
- **CSS**: `apps/retro_hex_chat_web/assets/css/`

---

## Phase 1: Setup

**Purpose**: No new project setup needed — this feature extends existing infrastructure. Phase is empty.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend the KeyBindings domain module with categories, metadata registry, and new action definitions. This is the foundation ALL user stories depend on.

**CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundation

- [x] T001 [P] Write unit tests for `KeyBindings.registry/1` that returns all shortcuts with action, category, label, description, binding, default_binding, and customizable fields in `apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs`
- [x] T002 [P] Write unit tests for `KeyBindings.categories/1` that groups registry entries by category (`:navigation`, `:chat`, `:formatting`, `:system`) in `apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs`
- [x] T003 [P] Write unit tests for 12 new actions (toggle_cheatsheet, window_next, window_prev, window_1..9) with correct default bindings and categories in `apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs`
- [x] T004 [P] Write unit tests verifying `open_help` action no longer has a default keyboard binding (menu-only) in `apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs`

### Implementation for Foundation

- [x] T005 Extend `KeyBindings` module with `@action_metadata` map containing category, label, description, and customizable flag for all 21 actions (9 existing + 12 new) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex`
- [x] T006 Implement `KeyBindings.registry/1` and `KeyBindings.categories/1` functions with @spec annotations in `apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex`
- [x] T007 Update `KeyBindings.defaults/0` to include 12 new action bindings (toggle_cheatsheet: Ctrl+Shift+/, window_next: Ctrl+Shift+], window_prev: Ctrl+Shift+[, window_1..9: Ctrl+Shift+1..9) and remove keyboard binding from `open_help` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex`
- [x] T008 Add search highlight CSS classes (`.search-highlight` yellow background, `.search-highlight-active` brighter/outlined) to `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T009 Verify all foundation tests pass — run `mix test apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs`

**Checkpoint**: KeyBindings registry with 21 actions, categories, and metadata is ready. All user stories can now begin.

---

## Phase 3: User Story 1 - Keyboard Shortcut Cheatsheet Dialog (Priority: P1) MVP

**Goal**: Users can press Ctrl+Shift+/ to open a read-only retro-styled dialog showing all keyboard shortcuts organized by category. Dialog closes on Escape/X, reflects custom bindings.

**Independent Test**: Open cheatsheet, verify all 4 categories render with correct shortcuts, close dialog, verify focus returns to input.

### Tests for User Story 1

- [x] T010 [P] [US1] Write component tests for `cheatsheet_dialog` verifying it renders 4 categories (Navigation, Chat, Formatting, System) with correct shortcut entries from KeyBindings.registry/1 in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/cheatsheet_dialog_test.exs`
- [x] T011 [P] [US1] Write LiveView tests for toggle_cheatsheet event: open on Ctrl+Shift+/, close on Escape, close on X button, toggle behavior, read-only (no text inputs), custom binding reflection in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`

### Implementation for User Story 1

- [x] T012 [US1] Create `CheatsheetDialog` function component with retro window styling, 4 category sections, shortcut table (Action | Binding), accepts `bindings` assign in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/cheatsheet_dialog.ex`
- [x] T013 [US1] Add `cheatsheet_visible` assign (default: false) to ChatLive `assign_defaults` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T014 [US1] Add `toggle_cheatsheet` handler to `KeyboardEvents` that toggles `cheatsheet_visible` assign, and add cheatsheet to the Escape dismiss hierarchy in `dismiss_topmost/1` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/keyboard_events.ex`
- [x] T015 [US1] Render `CheatsheetDialog` component in ChatLive template, passing `@cheatsheet_visible` and current keybindings in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T016 [US1] Verify all US1 tests pass — run `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/cheatsheet_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`

**Checkpoint**: Cheatsheet dialog is fully functional and testable. Users can discover all shortcuts.

---

## Phase 4: User Story 2 - Search Highlighting & Result Navigation (Priority: P2)

**Goal**: When search is active, matching text in message bodies is highlighted yellow in the chat. Users navigate between matches with Up/Down arrows. Counter shows "X of Y". Last search term remembered.

**Independent Test**: Open search, type a term, verify yellow highlights appear in chat area, navigate with arrows, verify counter updates, close and verify highlights removed.

### Tests for User Story 2

- [x] T017 [P] [US2] Write LiveView tests for search_input event triggering `push_event("search_highlight", ...)` with query and flags, and search_highlight_count event updating assigns in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`
- [x] T018 [P] [US2] Write LiveView tests for search_next/search_prev cycling search_current_index with wraparound, pushing `search_scroll_to` event, and close_search pushing `search_clear_highlights` in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`
- [x] T019 [P] [US2] Write LiveView test for search_last_query: closing search saves query to search_last_query, reopening pre-fills it in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`

### Implementation for User Story 2

- [x] T020 [US2] Create `SearchHighlightHook` JS hook that handles `search_highlight` (scan `.chat-content`/`.chat-action` text nodes via TreeWalker, wrap matches in `<mark class="search-highlight">`), `search_scroll_to` (activate Nth match with `.search-highlight-active`, scrollIntoView center), `search_clear_highlights` (unwrap all marks), and pushes `search_highlight_count` back to server in `apps/retro_hex_chat_web/assets/js/hooks/search_highlight_hook.js`
- [x] T021 [US2] Register `SearchHighlightHook` in `apps/retro_hex_chat_web/assets/js/app.js` and attach hook to hidden div in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T022 [US2] Add new search assigns to ChatLive `assign_defaults`: `search_last_query` (string, ""), `search_error` (nil) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T023 [US2] Update `SearchEvents` to: (a) on `search_input`, push_event `search_highlight` with query; (b) on `search_next`/`search_prev`, push_event `search_scroll_to` with index; (c) on `close_search`, push_event `search_clear_highlights` and save query to `search_last_query`; (d) on `toggle_search`, pre-fill from `search_last_query`; (e) handle `search_highlight_count` to update `search_result_count` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/search_events.ex`
- [x] T024 [US2] Update `SearchBar` component to pass Up/Down arrow keypresses in the search input as `search_navigate` event (phx-keydown on input) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/search_bar.ex`
- [x] T025 [US2] Verify all US2 tests pass — run `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`

**Checkpoint**: Search highlighting with yellow background, result navigation, counter, and term memory all functional.

---

## Phase 5: User Story 3 - Global Shortcut Dispatcher (Priority: P3)

**Goal**: Keyboard shortcuts work from anywhere in the app (not just chat input). Global JS hook intercepts registered Ctrl+Shift+Key combos and dispatches actions to the server. Uses bubble-up pattern so per-element hooks (formatting) fire first.

**Independent Test**: Focus the nicklist, press Ctrl+Shift+F — search opens. Focus treebar, press Ctrl+Shift+O — Options opens. Verify unregistered keys propagate normally.

### Tests for User Story 3

- [x] T026 [P] [US3] Write LiveView tests for `shortcut_action` event dispatching to correct handlers: "toggle_search" opens search, "toggle_options_dialog" opens options, "toggle_cheatsheet" opens cheatsheet in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`
- [x] T027 [P] [US3] Write LiveView test for custom binding dispatch: user has rebound toggle_search, verify new binding triggers search and old binding does not in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`

### Implementation for User Story 3

- [x] T028 [US3] Create `ShortcutDispatcherHook` JS hook that: (a) on mount, receives binding map via `update_bindings` push_event; (b) attaches document-level `keydown` listener; (c) checks `e.defaultPrevented` for bubble-up pattern; (d) matches key+modifiers against binding map; (e) pushes `shortcut_action` event with matched action; (f) calls `preventDefault()` for consumed events in `apps/retro_hex_chat_web/assets/js/hooks/shortcut_dispatcher_hook.js`
- [x] T029 [US3] Register `ShortcutDispatcherHook` in `apps/retro_hex_chat_web/assets/js/app.js` and attach hook to hidden div in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T030 [US3] Add `shortcut_action` handler to `KeyboardEvents` that takes `%{"action" => action_string}`, converts to atom via safe_to_action, and dispatches to the appropriate existing handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/keyboard_events.ex`
- [x] T031 [US3] Push `update_bindings` event on mount via `push_initial_preferences` and after options_apply via `apply_draft` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T032 [US3] Verified `autocomplete_hook.js` already calls `e.stopPropagation()` on formatting shortcuts (line 225) — no change needed
- [x] T033 [US3] Verify all US3 tests pass — run `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`

**Checkpoint**: All shortcuts work globally regardless of focus state. Formatting shortcuts still work in input.

---

## Phase 6: User Story 4 - Window Navigation Shortcuts (Priority: P4)

**Goal**: Users can cycle through channels/PMs with Ctrl+Shift+]/[ and jump to window N with Ctrl+Shift+1..9. Treebar updates to show active window.

**Independent Test**: Join 3 channels, press Ctrl+Shift+] — next channel activates. Press Ctrl+Shift+[ — wraps to last. Press Ctrl+Shift+2 — second channel activates. Press Ctrl+Shift+9 — nothing happens.

**Depends on**: US3 (global dispatcher must be working to intercept navigation shortcuts)

### Tests for User Story 4

- [x] T034 [P] [US4] Write LiveView tests for `window_next`/`window_prev` events: cycling forward/backward through channels and PMs in treebar order, wraparound behavior in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs`
- [x] T035 [P] [US4] Write LiveView tests for `window_select` event: direct access to windows 1-9, out-of-bounds does nothing, Status window excluded from numbered shortcuts in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs`

### Implementation for User Story 4

- [x] T036 [US4] Add `window_list` and `window_index` assigns to ChatLive `assign_defaults`. Implement `compute_window_list/1` helper that builds ordered list from `@channels` + `@pm_conversations` (Status included for cycling). Update window_list on channel join/part/PM open in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T037 [US4] Create `NavigationEvents` module with `handle_event` for `window_next` (increment index with wraparound, dispatch switch_channel/switch_pm/switch_to_status), `window_prev` (decrement with wraparound), and `window_select` (1-based index into channels+PMs, ignoring Status, no-op if out of bounds) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/navigation_events.ex`
- [x] T038 [US4] Wire `NavigationEvents` into ChatLive by adding `use` or delegating events, and add window_next/window_prev/window_1..9 action dispatch to `KeyboardEvents.shortcut_action` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/keyboard_events.ex`
- [x] T039 [US4] Verify all US4 tests pass — run `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs`

**Checkpoint**: Window navigation via keyboard fully functional. Users can navigate without the mouse.

---

## Phase 7: User Story 5 - Search Filters (Priority: P5)

**Goal**: Users can toggle Case-sensitive, Regex, and My-mentions filters in the search bar. Filters update results immediately. Invalid regex shows inline error.

**Independent Test**: Search "error" with case-sensitive on — only lowercase matches. Search `error|warn` with regex on — both match. Type `[invalid` — error shown. Toggle my-mentions — only messages with user's nick match.

**Depends on**: US2 (search highlighting must be working)

### Tests for User Story 5

- [x] T040 [P] [US5] Write unit tests for `Search.valid_regex?/1` accepting valid patterns and rejecting invalid ones in `apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs`
- [x] T041 [P] [US5] Write integration tests for `Search.search_messages/3` with `case_sensitive: true`, `regex: true`, and `nick_filter: "alice"` options in `apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs`
- [x] T042 [P] [US5] Write LiveView tests for `search_toggle_filter` event: toggling each filter updates assigns and re-triggers push_event with updated flags, invalid regex sets `search_error` in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`

### Implementation for User Story 5

- [x] T043 [US5] Add `valid_regex?/1` function to `Search` module. Extend `search_messages/3` and `count_matches/3` to accept `case_sensitive`, `regex`, and `nick_filter` keyword options. For regex: use PostgreSQL `~` (case-sensitive) or `~*` (case-insensitive) operators. For nick_filter: add WHERE clause on sender nickname in `apps/retro_hex_chat/lib/retro_hex_chat/chat/search.ex`
- [x] T044 [US5] Add filter assigns to ChatLive `assign_defaults`: `search_case_sensitive` (false), `search_regex` (false), `search_my_mentions` (false) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T045 [US5] Add `search_toggle_filter` handler to `SearchEvents` that toggles the specified filter assign, validates regex if regex mode is active (sets `search_error` on invalid), and re-triggers `push_event("search_highlight", ...)` with updated flags in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/search_events.ex`
- [x] T046 [US5] Update `SearchBar` component to render 3 filter checkboxes (Case-sensitive, Regex, My mentions) with `phx-click="search_toggle_filter"` events, and display `@search_error` inline when present in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/search_bar.ex`
- [x] T047 [US5] Update `SearchHighlightHook` to handle `case_sensitive`, `regex`, and `my_mentions` flags in the `search_highlight` event: construct RegExp with appropriate flags, filter message elements by `data-nick` attribute for my-mentions, handle invalid regex gracefully (do nothing) in `apps/retro_hex_chat_web/assets/js/hooks/search_highlight_hook.js`
- [x] T048 [US5] Verify all US5 tests pass — run `mix test apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`

**Checkpoint**: All search filters functional. Case-sensitive, regex, and my-mentions work independently and in combination.

---

## Phase 8: User Story 6 - Search in History (Priority: P6)

**Goal**: Users toggle "Search history" to extend search into database-stored messages. Historical results appear with visual distinction. Navigation scrolls to historical matches.

**Independent Test**: Send messages, enable "Search history", search a term — counter includes DB results. Navigate to a historical result — message loads in context.

**Depends on**: US2 (highlighting), US5 (filters applied to DB queries too)

### Tests for User Story 6

- [x] T049 [P] [US6] Write integration tests for `Search.search_messages/3` returning results beyond currently loaded messages (test with known DB data and limit/offset) in `apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs`
- [x] T050 [P] [US6] Write LiveView tests for history search: toggling `search_history` triggers DB query via `Search.search_messages/3`, result count combines client + DB matches, navigating to historical result loads context in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`

### Implementation for User Story 6

- [x] T051 [US6] Add `search_history` assign (false) to ChatLive `assign_defaults` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T052 [US6] Extend `SearchEvents` to handle history toggle: when `search_history` is true and query is non-empty, call `Search.search_messages/3` with current filters, store results in `search_results`, combine count with client-side count for `search_result_count` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/search_events.ex`
- [x] T053 [US6] Update `SearchBar` component to render "Search history" checkbox with `phx-click="search_toggle_filter"` for the "history" filter in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/search_bar.ex`
- [x] T054 [US6] Implement navigation to historical results: when navigating past client-side matches, load the historical message and its surrounding context (±10 messages) into the chat stream and scroll to it in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/search_events.ex`
- [x] T055 [US6] Verify all US6 tests pass — run `mix test apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs`

**Checkpoint**: Full search with history, filters, highlighting, and navigation complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, Options dialog updates, edge cases, CI validation

- [x] T056 [P] Add help topic for cheatsheet dialog in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/` explaining Ctrl+Shift+/ shortcut, category layout, and custom binding reflection
- [x] T057 [P] Add help topic for search enhancements (highlighting, filters, history search, keyboard navigation) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/`
- [x] T058 [P] Update existing keyboard shortcuts help topic with new navigation shortcuts (Ctrl+Shift+]/[, Ctrl+Shift+1..9), cheatsheet reference, and cross-references to new topics in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex`
- [x] T059 Update Options dialog Key Bindings panel to show all 21 actions (including new navigation and cheatsheet actions) with correct categories in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T060 Handle edge case: channel switch while search is active resets search state and clears highlights via `push_event("search_clear_highlights")` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/search_events.ex` or core_events.ex
- [x] T061 Run full CI-equivalent validation pipeline: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `mix test --include e2e`, `mix dialyzer`
- [x] T062 Fix any CI failures from T061 — all 5 checks must pass before feature is complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Empty — no new project setup needed
- **Phase 2 (Foundation)**: No dependencies — start immediately. BLOCKS all user stories.
- **Phase 3 (US1 Cheatsheet)**: Depends on Phase 2 only
- **Phase 4 (US2 Search Highlighting)**: Depends on Phase 2 only
- **Phase 5 (US3 Global Dispatcher)**: Depends on Phase 2 only
- **Phase 6 (US4 Window Navigation)**: Depends on Phase 2 + Phase 5 (US3 dispatcher)
- **Phase 7 (US5 Search Filters)**: Depends on Phase 2 + Phase 4 (US2 highlighting)
- **Phase 8 (US6 History Search)**: Depends on Phase 4 (US2) + Phase 7 (US5 filters)
- **Phase 9 (Polish)**: Depends on all desired user stories being complete

### User Story Dependencies

```
Phase 2 (Foundation)
  ├──→ US1 (Cheatsheet)          [independent]
  ├──→ US2 (Search Highlighting) [independent]
  ├──→ US3 (Global Dispatcher)   [independent]
  │      └──→ US4 (Window Nav)   [depends on US3]
  └──→ US2 ──→ US5 (Filters)    [depends on US2]
                  └──→ US6 (History) [depends on US2 + US5]
```

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- Domain logic before web layer
- Server-side before client-side (JS hooks)
- Core implementation before integration
- Verify tests pass at checkpoint

### Parallel Opportunities

- **Phase 2**: T001-T004 (all test tasks) can run in parallel
- **After Phase 2**: US1, US2, and US3 can start in parallel (no cross-dependencies)
- **Within each story**: Test tasks marked [P] can run in parallel
- **Phase 9**: T056-T058 (help topics) can run in parallel

---

## Parallel Example: After Foundation Complete

```
# Launch US1, US2, US3 in parallel:
Stream 1: T010 → T011 → T012 → T013 → T014 → T015 → T016 (Cheatsheet)
Stream 2: T017-T019 → T020 → T021 → T022 → T023 → T024 → T025 (Search Highlighting)
Stream 3: T026-T027 → T028 → T029 → T030 → T031 → T032 → T033 (Global Dispatcher)

# Then sequentially:
Stream 2 done → US5 (Filters): T040-T042 → T043-T048
Stream 3 done → US4 (Window Nav): T034-T035 → T036-T039
US2 + US5 done → US6 (History): T049-T050 → T051-T055
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundation (KeyBindings registry extension)
2. Complete Phase 3: User Story 1 (Cheatsheet dialog)
3. **STOP and VALIDATE**: Users can discover all shortcuts via Ctrl+Shift+/
4. Deploy/demo if ready

### Incremental Delivery

1. Phase 2 → Foundation ready
2. US1 (Cheatsheet) → Shortcut discovery (MVP!)
3. US2 (Search Highlighting) → Visual search
4. US3 (Global Dispatcher) → Shortcuts work everywhere
5. US4 (Window Navigation) → Keyboard-driven channel switching
6. US5 (Search Filters) → Precise search
7. US6 (History Search) → Full search across all messages
8. Polish → Help docs, edge cases, CI validation

### Sequential Solo Strategy (Recommended)

1. Foundation → US1 → US3 → US2 → US4 → US5 → US6 → Polish
2. Rationale: US3 (dispatcher) enables US1's shortcut to work globally, then US2 (highlighting) enables US5/US6 search enhancements

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All public functions MUST have @spec annotations (Constitution Principle VI)
- Help topics are MANDATORY for all new features (Constitution Principle XI)
- Only Ctrl+Shift+Key patterns — never override browser shortcuts
- Commit after each completed user story (not after each task)
- Stop at any checkpoint to validate story independently
