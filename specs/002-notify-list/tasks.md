# Tasks: Notify List (Buddy List)

**Input**: Design documents from `/specs/002-notify-list/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — Constitution IV mandates TDD. Tests are written before or alongside implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database schema, in-memory structs, and core context module that all stories depend on.

- [x] T001 Create migration for `notify_list_entries` and `notify_list_settings` tables in `apps/retro_hex_chat/priv/repo/migrations/XXXXXXXXXX_create_notify_list_tables.exs` — two tables per data-model.md: `notify_list_entries` (id, owner_nickname FK→registered_nicks ON DELETE CASCADE, tracked_nickname, note varchar(200), last_seen_at, timestamps) with unique index on `lower(owner_nickname), lower(tracked_nickname)` and index on `owner_nickname`; `notify_list_settings` (owner_nickname PK FK→registered_nicks ON DELETE CASCADE, auto_whois boolean default false, timestamps). Run `mix ecto.migrate`.
- [x] T002 [P] Create `NotifyListEntry` Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list_entry.ex` — schema for `notify_list_entries` table with fields: owner_nickname, tracked_nickname, note, last_seen_at. Add changeset/2 with validations: required [:owner_nickname, :tracked_nickname], validate_length note max 200, validate_length nicknames max 16. Add `@type t :: %__MODULE__{}`.
- [x] T003 [P] Create `NotifyListSettings` Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list_settings.ex` — schema for `notify_list_settings` table with fields: owner_nickname (PK), auto_whois. Add changeset/2. Add `@type t :: %__MODULE__{}`.
- [x] T004 [P] Create `NotifyEntry` struct in `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_entry.ex` — in-memory runtime struct with fields: tracked_nickname (String.t()), note (String.t() | nil), last_seen_at (DateTime.t() | nil), online (boolean(), default false). Add `@type t :: %__MODULE__{}` and `new/1` constructor.
- [x] T005 [P] Write unit tests for `NotifyListEntry` schema in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_list_entry_test.exs` — test valid changeset, required fields, note length validation (200 char limit), nickname length validation.
- [x] T006 [P] Write unit tests for `NotifyListSettings` schema in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_list_settings_test.exs` — test valid changeset, default auto_whois false.
- [x] T007 [P] Write unit tests for `NotifyEntry` struct in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_entry_test.exs` — test new/1, default online false, field access.

**Checkpoint**: Database tables exist, Ecto schemas compile, struct tests pass.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core `NotifyList` context module with CRUD + persistence, Session extension, and NickServ identify hook. MUST be complete before any user story.

**CRITICAL**: No user story work can begin until this phase is complete.

### Tests First

- [x] T008 Write unit tests for `Presence.NotifyList` in-memory CRUD operations in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_list_test.exs` — test: new/0 returns empty list with default settings; add_entry/4 adds buddy with owner_nickname, nickname, and note; add_entry/4 returns :self_add when nickname matches owner_nickname (case-insensitive); add_entry/4 returns :duplicate for case-insensitive match; add_entry/4 returns :list_full at 50 entries; remove_entry/2 removes by nickname case-insensitive; remove_entry/2 returns :not_found; update_note/3 updates note; update_note/3 truncates to 200 chars; update_nickname/3 renames tracked buddy; set_online/3 sets online status; set_online/3 updates last_seen_at when going offline; tracking?/2 case-insensitive check; sorted_entries/1 returns online first then offline alphabetically; count/1 and full?/1.
- [x] T009 Write integration tests for `Presence.NotifyList` persistence in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_list_test.exs` — test: save/2 persists entries for registered user; load/1 restores all entries and notes; save_entry/2 upserts single entry; delete_entry/2 removes from DB; save_settings/2 persists auto_whois; load/1 returns :not_found for unknown user; ON DELETE CASCADE removes entries when registered nick is dropped.
- [x] T010 Write unit tests for Session notify list extensions in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs` — add tests for: new/1 initializes with empty notify_list; set_notify_list/2 replaces notify list; get_notify_list/1 returns current list.

### Implementation

- [x] T011 Implement `Presence.NotifyList` in-memory CRUD functions in `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list.ex` — implement per contract: new/0, add_entry/4 (owner_nickname, nickname, note — checks self-add via owner_nickname), remove_entry/2, update_note/3, update_nickname/3, set_online/3, set_auto_whois/2, tracking?/2, online_buddies/1, offline_buddies/1, sorted_entries/1, count/1, full?/1. Internal representation: `%{entries: [NotifyEntry.t()], settings: %{auto_whois: boolean()}}`. All nickname comparisons case-insensitive via `String.downcase/1`.
- [x] T012 Implement `Presence.NotifyList` persistence functions in `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list.ex` — implement: save/2 (upsert all entries + settings for owner), load/1 (query all entries + settings, return notify_list with online: false), save_entry/2 (single upsert), delete_entry/2 (single delete), save_settings/2 (upsert settings). Use `Repo.insert/2` with `on_conflict: :replace_all` for upserts.
- [x] T013 Extend `Session` struct in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` — add field `notify_list` with default `Presence.NotifyList.new()`. Add functions: `set_notify_list/2`, `get_notify_list/1`. Update `@type t` to include `notify_list: map()`.
- [x] T014 Add NickServ identify broadcast in `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_serv.ex` — in `mark_identified/2`, after adding to identified MapSet, broadcast `{:nickserv_identified, %{nickname: nickname}}` to `"user:#{nickname}"` via PubSub. Write test in `apps/retro_hex_chat/test/retro_hex_chat/services/nick_serv_test.exs` verifying the broadcast is emitted on successful identify.
- [x] T015 Add `"presence:global"` PubSub broadcasts in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — on mount (when connected), broadcast `{:user_connected, %{nickname: nickname}}` to `"presence:global"` and subscribe to `"presence:global"`. In terminate/2, broadcast `{:user_disconnected, %{nickname: nickname}}` to `"presence:global"`. Write test in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_status_test.exs` verifying broadcasts are emitted.

**Checkpoint**: `Presence.NotifyList` context fully functional with CRUD + persistence. Session extended. NickServ broadcasts on identify. Global presence topic active. All unit + integration tests pass. Run `make lint`.

---

## Phase 3: User Story 1 — Manage Buddy List Entries (Priority: P1) MVP

**Goal**: Users can add/remove/edit buddies in their notify list. Registered users' lists persist across sessions via NickServ identify. Guests get in-memory-only lists.

**Independent Test**: Add, edit, remove entries via UI or commands. Verify persistence after re-identify for registered users.

### Tests First

- [x] T016 Write LiveView tests for notify list management in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_test.exs` — test: add buddy via ChatLive event updates session notify list; remove buddy via ChatLive event; edit note via ChatLive event; reject self-add with friendly message; reject add at 50 entries; reject duplicate (case-insensitive); on `:nickserv_identified` event, load notify list from DB into session; guest user has in-memory-only list.

### Implementation

- [x] T017 [US1] Wire ChatLive `handle_info` for `:nickserv_identified` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — when receiving `{:nickserv_identified, %{nickname: nick}}`, call `NotifyList.load/1` to fetch from DB, then `Session.set_notify_list/2` to update session. If load returns :not_found, keep current (empty or guest) list. Mark session as identified.
- [x] T018 [US1] Wire ChatLive `handle_event` for notify list CRUD in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — handle events: `"notify_add"` (params: nickname, note) → call `NotifyList.add_entry/4` passing session nickname as owner_nickname for self-add check, persist if identified; `"notify_remove"` (params: nickname) → call `NotifyList.remove_entry/2`, persist if identified; `"notify_edit"` (params: nickname, note) → call `NotifyList.update_note/3`, persist if identified. On error, display system message. Update session assigns after each operation.
- [x] T019 [US1] Implement persistence sync helper in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — private function `maybe_persist_notify_list/1` that checks `session.identified` and if true, calls `NotifyList.save/2` with the owner nickname. Called after every CRUD operation. Async (Task.start) to avoid blocking the UI.

**Checkpoint**: US1 complete — buddies can be added/removed/edited, lists persist for registered users. Test with `/notify add` command (wired in US5) or directly via LiveView events. All tests green. `make lint` clean.

---

## Phase 4: User Story 2 — Online/Offline Notifications (Priority: P2)

**Goal**: When a tracked buddy connects or disconnects, the user sees a system message in the Status window. Rapid events are debounced. Nickname renames update entries.

**Independent Test**: Track a buddy, have them connect/disconnect, verify Status window messages appear. Verify debounce with rapid events.

### Tests First

- [x] T020 Write LiveView tests for presence notifications in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_test.exs` — test: receiving `:user_connected` for tracked buddy adds "online" system message to status stream and updates entry online status; receiving `:user_disconnected` for tracked buddy adds "offline" message, updates last_seen_at; receiving events for non-tracked users are ignored; debounce: rapid connect/disconnect within 10s produces at most 1 online + 1 offline message; removing buddy suppresses pending offline notification.
- [x] T021 [P] Write unit tests for debounce logic in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_list_test.exs` — test debounce helper functions if extracted, or test via LiveView integration.
- [x] T022 [P] Write LiveView tests for nickname rename tracking in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_test.exs` — test: receiving `:nick_changed` where old nick is in notify list updates the entry's tracked_nickname to new nick; system message in status window says "* Your notify list buddy Alice is now known as Alice2"; persist rename to DB if identified.

### Implementation

- [x] T023 [US2] Wire ChatLive `handle_info` for `:user_connected` / `:user_disconnected` from `"presence:global"` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — on event, check `NotifyList.tracking?/2`. If tracked, start debounce timer via `Process.send_after(self(), {:notify_debounce, nickname, status}, 10_000)`. Store pending timers in assigns `notify_debounce_timers` (map of nickname → {timer_ref, status}). If opposite event arrives for same nickname within window, cancel old timer and start new one.
- [x] T024 [US2] Implement debounce timer handling in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `handle_info` for `{:notify_debounce, nickname, status}`. When timer fires: update entry via `NotifyList.set_online/3`; insert system message into `:status_messages` stream ("* Alice is now online" or "* Alice has gone offline"); update last_seen_at on offline; clean up timer from assigns; persist if identified.
- [x] T025 [US2] Extend existing `:nick_changed` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — after existing nicklist update logic, check if `old_nick` is in notify list via `NotifyList.tracking?/2`. If so, call `NotifyList.update_nickname/3`, insert rename message into `:status_messages` stream, persist if identified.
- [x] T026 [US2] Initialize `notify_debounce_timers` assign in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in `assign_defaults/2`, add `notify_debounce_timers: %{}`. Clean up all timers in `terminate/2`.

**Checkpoint**: US2 complete — online/offline notifications with debounce and rename tracking. Status window shows messages. All tests green. `make lint` clean.

---

## Phase 5: User Story 3 — Notify List Window (Priority: P3)

**Goal**: Dedicated retro-style window showing all buddies with columns (Nickname, Status, Notes, Last Seen), sorted online-first. Toolbar buttons for Add/Remove/Edit. Double-click online buddy opens PM.

**Independent Test**: Open window, verify columns and sort order. Add/remove via toolbar. Double-click online buddy to PM.

### Tests First

- [x] T027 Write LiveView tests for Notify List window in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_test.exs` — test: window opens on `"toggle_notify_list"` event; window shows all entries with correct columns; online buddies sorted above offline; clicking Add opens add form; submitting add form creates entry; clicking Remove on selected entry removes it; double-click online buddy opens PM conversation; double-click offline buddy does nothing; window closes on toggle.

### Implementation

- [x] T028 [US3] Create `NotifyListWindow` function component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/notify_list_window.ex` — retro-styled window with title "Notify List". Columns: Nickname, Status (green/grey circle icon), Notes, Last Seen (formatted datetime or "Never"). Toolbar with Add, Remove, Edit buttons. Accepts assigns: `entries` (sorted list from `NotifyList.sorted_entries/1`), `visible` (boolean), `selected_entry` (String.t() | nil). Emits events: `"toggle_notify_list"`, `"notify_add_dialog"`, `"notify_remove"`, `"notify_edit_dialog"`, `"notify_dblclick"`.
- [x] T029 [US3] Create Add/Edit dialog sub-component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/notify_list_window.ex` — modal dialog (reuse Dialog pattern) with fields: Nickname (text input, required, max 16 chars) and Notes (text input, optional, max 200 chars). For Edit mode, pre-fill current values with nickname read-only. Submit triggers `"notify_add"` or `"notify_edit"` event.
- [x] T030 [US3] Create `NotifyListHook` JS hook in `apps/retro_hex_chat_web/assets/js/hooks/notify_list_hook.js` — handle double-click on buddy rows: push `"notify_dblclick"` event with `{nickname: row.dataset.nickname}`. Handle row selection on single click: push `"notify_select"` with nickname.
- [x] T031 [US3] Wire Notify List window into ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add assigns: `show_notify_list: false`, `notify_selected: nil`, `show_notify_add_dialog: false`, `show_notify_edit_dialog: false`. Add `handle_event` for: `"toggle_notify_list"`, `"notify_select"`, `"notify_dblclick"` (open PM if buddy online), `"notify_add_dialog"` / `"notify_edit_dialog"` (show/hide dialogs). Render `<NotifyListWindow>` component in template. Add toolbar button to open window.
- [x] T032 [US3] Register JS hook in `apps/retro_hex_chat_web/assets/js/app.js` — import and register `NotifyListHook` in the LiveSocket hooks configuration.

**Checkpoint**: US3 complete — Notify List window fully functional with add/remove/edit/double-click-to-PM. retro-styled. All tests green. `make lint` clean.

---

## Phase 6: User Story 4 — Auto-Whois on Connect (Priority: P4)

**Goal**: Global toggle for auto-whois. When enabled and a buddy comes online, display their whois info (channels, status, etc.) as system messages in the Status window.

**Independent Test**: Enable auto-whois, have buddy connect, verify whois info appears in Status window.

### Tests First

- [x] T033 Write unit tests for `whois_info/1` in `apps/retro_hex_chat/test/retro_hex_chat/presence/notify_list_test.exs` — test: returns nickname, registered status, identified status, channels list, away status, away_message; returns :not_found for unknown user.
- [x] T034 [P] Write LiveView tests for auto-whois in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_test.exs` — test: with auto_whois enabled, buddy online triggers whois messages in status stream; with auto_whois disabled, no whois messages; toggle auto_whois updates settings and persists.

### Implementation

- [x] T035 [US4] Implement `whois_info/1` in `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list.ex` — aggregate data from: `NickServ.info/1` (registered?, identified?, registered_at, last_seen_at), `Tracker.list_users/1` across all channels (find which channels user is in, away status), channel `Server.get_state/1` for roles. Return map per contract. Handle not-found gracefully.
- [x] T036 [US4] Wire auto-whois into notification flow in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in the `:notify_debounce` handler, after emitting "online" notification, check `session.notify_list.settings.auto_whois`. If true, call `NotifyList.whois_info/1` and insert whois details as system messages into `:status_messages` stream (channels, away status, registered info).
- [x] T037 [US4] Wire auto-whois toggle in ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `handle_event("toggle_auto_whois", ...)` that calls `NotifyList.set_auto_whois/2`, updates session, persists settings if identified. Add toggle button/checkbox in Notify List window toolbar.

**Checkpoint**: US4 complete — auto-whois toggle works, whois info displayed on buddy connect. All tests green. `make lint` clean.

---

## Phase 7: User Story 5 — Slash Commands for Notify List (Priority: P5)

**Goal**: `/notify add|remove|edit|list` commands and bare `/notify` to open window. Full command-line management of the notify list.

**Independent Test**: Execute each command variant and verify correct response.

### Tests First

- [x] T038 Write unit tests for Notify command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/notify_test.exs` — test validate/1: valid for "", "add nick", "add nick some note", "remove nick", "edit nick new note", "list"; invalid for "add" (no nick), "edit nick" (no note), "remove" (no nick), "unknown_sub". Test execute/2: bare → :ui_action :open_notify_list; add → :ui_action :notify_add with nickname+note; remove → :ui_action :notify_remove with nickname; edit → :ui_action :notify_edit with nickname+note; list → :ui_action :notify_list_display (ChatLive formats the display since it has the session data).
- [x] T039 [P] Write LiveView integration tests for `/notify` commands in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_test.exs` — test end-to-end: type `/notify add Alice A note` → entry added, confirmation shown; type `/notify remove Alice` → entry removed; type `/notify list` → list displayed; type `/notify` → window opens; type `/notify edit Alice New note` → note updated.

### Implementation

- [x] T040 [US5] Create `Notify` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/notify.ex` — implement `Handler` behaviour. `validate/1`: parse subcommand (add/remove/edit/list/""), validate arg counts per contract. `execute/2`: bare → `{:ok, :ui_action, :open_notify_list, %{}}`; add → `{:ok, :ui_action, :notify_add, %{nickname: nick, note: note}}`; remove → `{:ok, :ui_action, :notify_remove, %{nickname: nick}}`; edit → `{:ok, :ui_action, :notify_edit, %{nickname: nick, note: note}}`; list → `{:ok, :ui_action, :notify_list_display, %{}}` (ChatLive handles formatting since it has the session/notify_list data). `help/0`: return help text.
- [x] T041 [US5] Register `/notify` in command registry in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` — add `"notify" => RetroHexChat.Commands.Handlers.Notify` to the `@commands` map.
- [x] T042 [US5] Wire `/notify` UI actions in ChatLive `handle_ui_action/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add clauses for: `:open_notify_list` → toggle window; `:notify_add` → call existing add logic from T018; `:notify_remove` → call existing remove logic; `:notify_edit` → call existing edit logic; `:notify_list_display` → format and display the buddy list as system messages in status window (reads from session.notify_list, formats each entry with online/offline status, note, last_seen). Reuse the same CRUD handlers wired in US1.

**Checkpoint**: US5 complete — all `/notify` commands work end-to-end. All tests green. `make lint` clean.

---

## Phase 8: User Story 3 (continued) — Status Window (Priority: P3)

**Goal**: The Status window is a persistent, always-visible system message area. It receives all notify list notifications and can receive future system events. Cannot be closed.

**Independent Test**: Status window visible on load. Notify events appear there. Cannot be closed.

### Tests First

- [x] T043 Write LiveView tests for Status window in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_status_test.exs` — test: Status window renders on mount (always present); system messages appear in status stream; messages have distinct styling for online (green) vs offline (grey); window cannot be closed (no close button); multiple messages accumulate in order.

### Implementation

- [x] T044 Create `StatusWindow` function component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_window.ex` — retro-styled window with title "Status". Scrollable message area using LiveView stream `:status_messages`. Each message is a system message with timestamp. Online notifications styled green, offline styled grey. No close button (always present). Accepts assigns: `status_messages` (stream).
- [x] T045 Wire Status window into ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — initialize `:status_messages` stream in `mount/3`. Render `<StatusWindow>` component in template (always visible, positioned in MDI layout). Add private helper `push_status_message/3` that inserts a timestamped message into the stream with type (:notify_online, :notify_offline, :notify_rename, :system).
- [x] T046 Refactor notification delivery to use Status window in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — update all notify event handlers (from T024, T025) to use `push_status_message/3` instead of direct stream_insert. Ensure whois messages (T036) also route through status window.

**Checkpoint**: Status window complete — always visible, receives all notify events with correct styling. All tests green. `make lint` clean.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, final integration, static analysis, coverage.

- [x] T047 Handle edge case: buddy not in any shared channel renames in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — if a tracked buddy renames but the user shares no channels with them, the `:nick_changed` broadcast won't reach the user. Add handling in `:user_disconnected` + `:user_connected` for "new nickname connects after old nickname disconnects" pattern. Document this limitation if not feasible without global rename broadcast.
- [x] T048 [P] Add `data-testid` attributes to Notify List window and Status window components for E2E testing in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/notify_list_window.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_window.ex`.
- [x] T049 [P] Write E2E tests for notify list full flow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notify_e2e_test.exs` — tag `@tag :e2e`. Test: open notify list window, add buddy, verify entry appears; remove buddy; buddy comes online, status window shows notification; `/notify add` command works; `/notify list` displays entries.
- [x] T050 Run full static analysis suite — `make lint` (mix format --check-formatted + mix credo --strict + mix dialyzer). Fix any warnings or type errors.
- [x] T051 Run full test suite — `make test` to ensure no regressions. Verify new tests pass alongside existing 822+ tests. Check test coverage does not regress.
- [x] T052 Run E2E tests — `mix test --only e2e` to verify end-to-end flows including new notify list E2E tests.

**Checkpoint**: All polish complete. Full suite green. Linters clean. Feature ready for review.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 2 + Phase 8 (Status window for message delivery)
- **Phase 5 (US3)**: Depends on Phase 2
- **Phase 6 (US4)**: Depends on Phase 4 (US2 — needs notification flow)
- **Phase 7 (US5)**: Depends on Phase 3 (US1 — needs CRUD logic to exist)
- **Phase 8 (Status Window)**: Depends on Phase 2
- **Phase 9 (Polish)**: Depends on all previous phases

### Recommended Execution Order

```
Phase 1 → Phase 2 → Phase 8 (Status Window) → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 7 (US5) → Phase 6 (US4) → Phase 9
```

Note: Phase 8 (Status Window) is moved early because US2 needs it for notification delivery. US3 (Notify List Window) and US5 (Commands) can be done in parallel once US1 is complete.

### Within Each Phase

- Tests MUST be written first and FAIL before implementation (TDD)
- Schemas/structs before context functions
- Context functions before LiveView integration
- LiveView integration before components

### Parallel Opportunities

- **Phase 1**: T002, T003, T004, T005, T006, T007 all parallelizable (different files)
- **Phase 2**: T008, T009, T010 can be written in parallel (test files)
- **Phase 4+5**: US2 (notifications) and US3 (window) can proceed in parallel once Status Window exists
- **Phase 7**: US5 (commands) can proceed in parallel with US3 if US1 CRUD is done
- **Phase 9**: T048, T049 parallelizable

---

## Parallel Example: Phase 1 Setup

```
# Launch all schema + struct creation together:
Task: T002 "Create NotifyListEntry schema"
Task: T003 "Create NotifyListSettings schema"
Task: T004 "Create NotifyEntry struct"

# Launch all tests together:
Task: T005 "Test NotifyListEntry schema"
Task: T006 "Test NotifyListSettings schema"
Task: T007 "Test NotifyEntry struct"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (schemas, migration)
2. Complete Phase 2: Foundational (context module, session, NickServ hook)
3. Complete Phase 3: US1 (buddy management CRUD)
4. **STOP and VALIDATE**: Add/remove/edit buddies, verify persistence
5. This delivers a functional buddy address book

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Status Window (Phase 8) → System message area ready
3. US1 (Phase 3) → Buddy management MVP
4. US2 (Phase 4) → Online/offline notifications → Core value delivered
5. US3 (Phase 5) → Notify List window → Full GUI experience
6. US5 (Phase 7) → Slash commands → Power user access
7. US4 (Phase 6) → Auto-whois → Enhancement
8. Polish (Phase 9) → E2E tests, edge cases → Production ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution IV (TDD): Tests written first, must fail before implementation
- Constitution VI: All new modules must have @spec and pass Credo+Dialyzer
- The `/notify` command handler returns `:ui_action` tuples that ChatLive routes to existing CRUD logic — no duplication
- Debounce timers live in LiveView assigns, cleaned up on terminate
- Persistence is incremental (save after each operation) not batch — immediate durability for registered users
