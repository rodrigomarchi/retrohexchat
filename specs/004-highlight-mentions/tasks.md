# Tasks: Highlight / Mentions

**Input**: Design documents from `/specs/004-highlight-mentions/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/events.md, quickstart.md

**Tests**: TDD is non-negotiable per Constitution Principle IV. Tests are written before or alongside implementation.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Foundational (Shared Infrastructure)

**Purpose**: Core structs, CSS classes, and Session extension that all user stories depend on

- [x] T001 Create HighlightWord struct (word, bg_color, position fields, @type t, new/1) in apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_word.ex
- [x] T002 [P] Add highlight CSS classes (.chat-message--highlighted default yellow background, .tree-highlight with @keyframes tree-flash animation) in apps/retro_hex_chat_web/assets/css/dark-theme.css
- [x] T003 [P] Add highlight_words field (map, default nil) with set_highlight_words/2 and get_highlight_words/1 to Session, update @type t in apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex

**Checkpoint**: Foundation ready — struct, CSS, and Session field exist for all user stories to build on

---

## Phase 2: User Story 1 — Own-Nick Highlighting (Priority: P1) 🎯 MVP

**Goal**: Messages mentioning the user's nickname get a distinct highlight background color automatically, with no configuration needed

**Independent Test**: Connect two users to same channel, have one mention the other's nick, verify message renders with highlight styling. Verify self-messages, partial words, URLs, and system messages are NOT highlighted.

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T004 [P] [US1] Write unit tests for Chat.Highlight.check/4 — own nick match, case-insensitive, partial word rejection, self-highlight prevention, URL exclusion, empty content, formatting code stripping, multiple words priority in apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_test.exs

### Implementation for User Story 1

- [x] T005 [US1] Implement Chat.Highlight module with check/4 function: strip formatting via Formatter.strip/1, mask URLs via ~r{https?://\S+}i, whole-word regex matching with \b and caseless, self-highlight prevention, priority logic (own nick > custom words in list order), return {:highlight, color} | :no_highlight in apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight.ex
- [x] T006 [US1] Modify ChatLive handle_info(%{event: "new_message"}) to call Chat.Highlight.check/4 for :message and :action types, decorate payload with highlighted: true and highlight_color before stream_insert in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T007 [US1] Modify ChatLive template to apply chat-message--highlighted class conditionally on message div and optional inline background-color style from highlight_color in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T008 [US1] Write LiveView tests for own-nick highlighting: message with nick highlighted, self-message not highlighted, system message not highlighted, case-insensitive match in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_highlight_test.exs

**Checkpoint**: Own-nick highlighting works end-to-end. Messages mentioning the user's nick show a yellow background. Self-messages, partial words, URLs, system messages are excluded.

---

## Phase 3: User Story 2 — Non-Active Channel Flash (Priority: P2)

**Goal**: When a highlight occurs in a channel the user is not currently viewing, the treebar entry for that channel flashes

**Independent Test**: Join two channels, view one, trigger highlight in the other, verify treebar entry has flash class. Switch to that channel, verify flash stops.

### Tests for User Story 2

- [x] T009 [P] [US2] Write component tests for TreeBar with highlight_channels: tree-highlight class applied, not applied for active channel, removed on switch in apps/retro_hex_chat_web/test/retro_hex_chat_web/components/treebar_test.exs

### Implementation for User Story 2

- [x] T010 [US2] Add highlight_channels assign (MapSet.new()) to ChatLive mount in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T011 [US2] Update ChatLive handle_info for new_message: when highlight detected and channel != active_channel, add channel to highlight_channels MapSet in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T012 [US2] Clear highlight_channels entry in ChatLive handle_event("switch_channel") via MapSet.delete in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T013 [US2] Add highlight_channels attr (:list, default []) to TreeBar component, apply tree-highlight class when channel in highlight_channels in apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex
- [x] T014 [US2] Pass highlight_channels={MapSet.to_list(@highlight_channels)} to TreeBar in ChatLive template in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T015 [US2] Write LiveView tests for treebar flash: highlight in non-active channel adds flash, switching clears flash, active channel highlight does not flash in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_highlight_test.exs

**Checkpoint**: TreeBar entries flash when highlights occur in non-active channels. Flashing stops when user switches to that channel.

---

## Phase 4: User Story 3 — Notification Sound (Priority: P3)

**Goal**: A notification sound plays when a highlight is triggered

**Independent Test**: Trigger a highlight, verify push_event("play_sound") is sent. Verify no sound for non-highlighted messages.

### Implementation for User Story 3

- [x] T016 [US3] Add push_event("play_sound", %{type: "mention"}) in ChatLive handle_info when highlight detected (gated by channel_muted?/1 helper that returns false for now) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T017 [US3] Add private channel_muted?/1 function (returns false, placeholder for future mute feature) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T018 [US3] Write LiveView tests for sound: push_event sent on highlight, not sent on non-highlight, not sent when channel_muted? returns true (test the hook point) in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_highlight_test.exs

**Checkpoint**: Notification sound plays on highlight via existing SoundHook. Mute hook point ready for future wiring.

---

## Phase 5: User Story 4 — Custom Highlight Words (Priority: P4)

**Goal**: Users can configure additional words that trigger highlighting beyond their own nickname

**Independent Test**: Add "phoenix" to highlight words in session, send message containing "phoenix", verify it highlights. Verify "going" does not match "go" (whole-word). Verify per-word custom color applied.

### Tests for User Story 4

- [x] T019 [P] [US4] Write unit tests for HighlightWords CRUD: new/0, add_entry/3 (validation, max 50, case-insensitive uniqueness), remove_entry/2, update_entry/3, entries/1 sorting in apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_words_test.exs

### Implementation for User Story 4

- [x] T020 [US4] Implement HighlightWords module: new/0, add_entry/3 with word validation (1-50 chars, trimmed, unique case-insensitive, bg_color 0-15 or nil, max 50 entries), remove_entry/2, update_entry/3, entries/1 in apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_words.ex
- [x] T021 [US4] Initialize Session.highlight_words via HighlightWords.new() in Session.new/1 in apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex
- [x] T022 [US4] Update ChatLive highlight check to pass session.highlight_words.entries to Chat.Highlight.check/4 (was passing [] before) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T023 [US4] Add unit tests for Highlight.check/4 with custom words: word match, custom color, priority (nick > custom), partial word rejection, multiple custom words in apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_test.exs
- [x] T024 [US4] Write LiveView tests for custom highlight word matching: message matching custom word highlighted, custom color applied, priority order respected in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_highlight_test.exs

**Checkpoint**: Custom highlight words trigger highlighting with optional per-word colors. Priority: own nick > custom words in list order.

---

## Phase 6: User Story 5 — Configuration Dialog + Persistence (Priority: P5)

**Goal**: UI dialog for managing highlight words and database persistence for registered users

**Independent Test**: Open dialog, add/edit/remove words, verify changes take effect. For registered user, disconnect and reconnect, verify words restored.

### Migration & Schema

- [x] T025 [US5] Create migration for highlight_words table (id, owner_nickname FK→registered_nicks CASCADE, word varchar(50), bg_color integer CHECK 0-15, position integer, timestamps, unique index on lower(owner_nickname)+lower(word)) in apps/retro_hex_chat/priv/repo/migrations/*_create_highlight_words.exs
- [x] T026 [US5] Create HighlightWordEntry Ecto schema (belongs_to registered_nick via owner_nickname, changeset with validations) in apps/retro_hex_chat/lib/retro_hex_chat/accounts/highlight_word_entry.ex

### Persistence

- [x] T027 [P] [US5] Write persistence tests for HighlightWords save/load: save round-trip, load not_found, case-insensitive uniqueness, cascade delete in apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_words_test.exs
- [x] T028 [US5] Add save/2 (full replace: delete all + insert all in transaction) and load/1 (query entries, transform to HighlightWord structs, return {:ok, map} | {:error, :not_found}) to HighlightWords module in apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_words.ex
- [x] T029 [US5] Add HighlightWords.load(nick) call to ChatLive handle_info({:nickserv_identified, ...}) alongside existing notify_list/contacts/nick_colors loads in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T030 [US5] Add maybe_persist_highlight_words/2 private helper (async Task.start save if session.identified) to ChatLive in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex

### Dialog Component

- [x] T031 [P] [US5] Write component tests for HighlightDialog: renders word list, shows own nick as non-removable, add/edit/remove buttons, color picker in apps/retro_hex_chat_web/test/retro_hex_chat_web/components/highlight_dialog_test.exs
- [x] T032 [US5] Create HighlightDialog function component (98.css window chrome, title "Highlight Words", word list with color indicators, own nick non-removable first row, Add/Edit/Remove buttons, 16-color IRC palette picker) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/highlight_dialog.ex
- [x] T033 [US5] Add show_highlight_dialog assign (false), open_highlight_dialog and close_highlight_dialog event handlers to ChatLive in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T034 [US5] Add highlight:add, highlight:edit, highlight:remove event handlers to ChatLive (update session.highlight_words via HighlightWords CRUD, call maybe_persist_highlight_words) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T035 [US5] Wire HighlightDialog into ChatLive template (:if show_highlight_dialog), add menu bar "Highlight" item and Alt+H keyboard shortcut in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T036 [US5] Write LiveView tests for dialog: open/close, add word, edit color, remove word, persistence on identify round-trip, guest session (no persistence) in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_highlight_test.exs

**Checkpoint**: Full configuration dialog works. Registered users' highlight words persist across sessions. Guests get session-only words.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: E2E tests, data-testid attributes, linter verification

- [x] T037 [P] Add data-testid attributes to highlight-related elements (highlighted messages, treebar flash entries, dialog elements) across apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ and live/chat_live.ex
- [x] T038 [P] Write E2E tests for full highlight flow: own-nick highlight rendering, treebar flash on non-active channel, custom word highlight with color, dialog add/edit/remove, persistence after identify in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_highlight_e2e_test.exs
- [x] T039 Run mix format --check-formatted + mix credo --strict + mix dialyzer and fix any issues
- [x] T040 Run make test (full suite excluding E2E) and verify 0 failures, coverage non-regressed
- [x] T041 Run make test.all (including E2E) and verify 0 failures

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies — can start immediately
- **US1 (Phase 2)**: Depends on Phase 1 completion — CORE MVP
- **US2 (Phase 3)**: Depends on US1 (needs highlight detection in handle_info)
- **US3 (Phase 4)**: Depends on US1 (needs highlight detection in handle_info)
- **US4 (Phase 5)**: Depends on US1 (extends matching engine with custom words)
- **US5 (Phase 6)**: Depends on US4 (provides UI and persistence for custom words)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1 (Foundational)
    │
    ▼
Phase 2 (US1: Own-Nick Highlighting) 🎯 MVP
    │
    ├──────────┬──────────┐
    ▼          ▼          ▼
Phase 3    Phase 4    Phase 5
(US2:      (US3:      (US4: Custom
 Flash)     Sound)     Words)
    │          │          │
    │          │          ▼
    │          │      Phase 6
    │          │      (US5: Dialog
    │          │       + Persist)
    │          │          │
    ▼          ▼          ▼
Phase 7 (Polish & E2E)
```

### Parallel Opportunities

**Within Phase 1** (all different files):
- T001 (HighlightWord struct) + T002 (CSS) + T003 (Session) can run in parallel

**After US1 completes** (Phases 3, 4, 5 are independent):
- US2 (TreeBar flash) and US3 (Sound) can proceed in parallel
- US4 (Custom words) can proceed in parallel with US2/US3

**Within Phase 6** (different files):
- T027 (persistence tests) + T031 (dialog tests) can run in parallel

**Within Phase 7**:
- T037 (data-testid) + T038 (E2E tests) can run in parallel

---

## Parallel Example: After US1 Completes

```bash
# These can all run simultaneously after Phase 2 (US1) is done:

# Stream 1: US2 (TreeBar flash)
T009 → T010 → T011 → T012 → T013 → T014 → T015

# Stream 2: US3 (Sound)
T016 → T017 → T018

# Stream 3: US4 (Custom words) → US5 (Dialog + Persistence)
T019 → T020 → T021 → T022 → T023 → T024 → T025 → ... → T036
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Foundational (T001-T003)
2. Complete Phase 2: US1 — Own-Nick Highlighting (T004-T008)
3. **STOP and VALIDATE**: Verify own-nick highlighting works end-to-end
4. This alone delivers the most impactful feature — every IRC client highlights the user's nick

### Incremental Delivery

1. Phase 1 + Phase 2 → **MVP**: Own-nick highlighting works ✓
2. Add Phase 3 (US2) → TreeBar flashes on non-active channel highlights ✓
3. Add Phase 4 (US3) → Sound plays on highlight ✓
4. Add Phase 5 (US4) → Custom highlight words work ✓
5. Add Phase 6 (US5) → Configuration dialog + persistence ✓
6. Phase 7 → E2E tests, polish, linter verification ✓

Each phase adds value without breaking previous phases.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Constitution Principle IV: TDD non-negotiable — test tasks precede implementation
- Existing SoundHook reused (US3) — zero new JS for sound
- Existing persistence pattern reused (US5) — identical to notify_list/contacts/nick_colors
- Mute feature doesn't exist yet — channel_muted?/1 returns false as hook point (FR-010 deferred)
- Nick change handled automatically — matching engine reads session.nickname at check time (FR-017)
