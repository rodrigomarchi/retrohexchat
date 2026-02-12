# Tasks: Notice System

**Input**: Design documents from `/specs/011-notice-system/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Included per Constitution Principle IV (Test-First Development — NON-NEGOTIABLE).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/retro_hex_chat/` (domain) and `apps/retro_hex_chat_web/` (web layer)
- Tests mirror source paths under `test/` in each app

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration, Session struct extension, ignore system extension, and command registration — shared foundations that all user stories depend on.

- [x] T001 Create database migration for `notice_routing_settings` table in `apps/retro_hex_chat/priv/repo/migrations/`. Table has `owner_nickname` as PK (FK to `registered_nicks`, ON DELETE CASCADE), `routing` string column (NOT NULL, default `"active"`), and timestamps. Follow the `perform_settings` migration pattern. Run `mix ecto.migrate` to apply.

- [x] T002 [P] Create Ecto schema `RetroHexChat.Chat.Schemas.NoticeRoutingSetting` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/notice_routing_setting.ex`. Define schema for `notice_routing_settings` table with `owner_nickname` (string, primary key), `routing` (string). Include changeset/2 that validates `routing` is one of `["active", "status", "sender"]`. Add `@spec` on all public functions.

- [x] T003 [P] Add `notice_routing` field to Session struct in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`. Add type `:active | :status | :sender` to `@type t`, add to `defstruct` with default `:active`. Add `get_notice_routing/1` and `set_notice_routing/2` functions with `@spec`. Follow the `auto_join_on_invite` getter/setter pattern.

- [x] T004 [P] Extend IgnoreEntry valid types in `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex`: add `:notices` to `@valid_types` list and `@type t` union. Extend IgnoreList type matching in `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex`: add `defp type_matches?(:notices, :notice), do: true` clause.

- [x] T005 [P] Register both new commands in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`: add `"notice" => RetroHexChat.Commands.Handlers.Notice` and `"notice_routing" => RetroHexChat.Commands.Handlers.NoticeRouting` to the `@commands` map.

- [x] T006 [P] Add `.chat-notice` CSS class in `apps/retro_hex_chat_web/assets/css/layout.css`. Use color `#cc6699` (muted pink/magenta). Place it after the existing `.chat-action` rule. Also add `.chat-notice-nick` for the `-Nick-` prefix styling (same color, no extra weight needed).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Domain module for notice routing CRUD and persistence — needed by both US1 (default routing) and US3 (configurable routing).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundational Phase

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T007 [P] Write unit tests for NoticeRouting domain module in `apps/retro_hex_chat/test/retro_hex_chat/chat/notice_routing_test.exs`. Test: `new/0` returns `%{routing: :active}`, `get_routing/1` returns atom, `set_routing/2` updates value, `set_routing/2` rejects invalid atoms. Tag with `@tag :unit`.

- [x] T008 [P] Write integration tests for NoticeRouting persistence in `apps/retro_hex_chat/test/retro_hex_chat/chat/notice_routing_test.exs` (same file, separate `describe` block). Test: `save/2` + `load/1` round-trip, `load/1` returns `{:error, :not_found}` for unknown user, `save/2` upserts existing row. Tag with `@tag :integration`.

- [x] T009 [P] Write unit tests for Session notice_routing functions in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs` (add to existing test file). Test: default routing is `:active`, `get_notice_routing/1`, `set_notice_routing/2`. Tag with `@tag :unit`.

- [x] T010 [P] Write unit tests for IgnoreEntry `:notices` type in `apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_entry_test.exs` (add to existing). Test: `:notices` is in `valid_types/0`, `valid_type?(:notices)` returns true. Write unit tests for IgnoreList `:notice` matching in `apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_list_test.exs` (add to existing). Test: `ignored?/3` with `ignore_type: :notices` matches `:notice` message type, `ignore_type: :all` matches `:notice`, `ignore_type: :messages` does NOT match `:notice`. Tag with `@tag :unit`.

### Implementation for Foundational Phase

- [x] T011 Create `RetroHexChat.Chat.NoticeRouting` domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/notice_routing.ex`. Implement: `new/0` → `%{routing: :active}`, `get_routing/1` → atom, `set_routing/2` → updated map (validate routing atom), `save/2` → upsert to DB via Ecto schema, `load/1` → load from DB and convert string to atom. Follow the `NotifyList`/`PerformList` pattern. Add `@spec` on all public functions.

**Checkpoint**: Foundation ready. Run `mix test --only unit` and `mix test --only integration` for notice-related tests. All should pass.

---

## Phase 3: User Story 1 - Send a Notice to a User (Priority: P1) 🎯 MVP

**Goal**: Users can send `/notice <nickname> <message>` and the recipient sees the notice in their active window with `-Nick-` formatting. No PM windows, sounds, or highlights.

**Independent Test**: Two connected users exchange notices — delivery, formatting, and negative constraints verified.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US1] Write unit tests for `/notice` command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/notice_test.exs`. Test: `validate("")` returns error with usage hint, `validate("Alice hello")` returns `:ok`, `execute([], ctx)` returns error, `execute(["Alice"], ctx)` returns error (no message), `execute(["Alice", "hello", "world"], ctx)` returns `{:ok, :notice, %{target: "Alice", content: "hello world"}}`, `help/0` returns correct map. Tag with `@tag :unit`.

- [x] T013 [P] [US1] Write LiveView tests for user notice delivery in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notice_test.exs`. Test: sending `/notice Alice hello` when Alice is online broadcasts `{:new_notice, payload}` to `user:Alice` topic, sending `/notice Unknown hello` when Unknown is not online shows "User not found: Unknown" error, receiving `{:new_notice, %{sender: "Bob", content: "hey"}}` renders notice with `-Bob-` prefix and `.chat-notice` class, receiving notice from ignored user is silently dropped (no stream insert), receiving notice does NOT trigger `play_sound` event, receiving notice does NOT create PM window or treebar entry. Tag with `@tag :liveview`.

### Implementation for User Story 1

- [x] T014 [P] [US1] Create `/notice` command handler `RetroHexChat.Commands.Handlers.Notice` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/notice.ex`. Implement `@behaviour RetroHexChat.Commands.Handler` with `validate/1`, `execute/2`, `help/0`. Parse target and content, return `{:ok, :notice, %{target: target, content: content}}`. Add `@spec` on all public functions.

- [x] T015 [US1] Add `handle_dispatch_result` clause for `{:ok, :notice, payload}` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. For user-targeted notices (target does NOT start with `#`): check if user is online via `RetroHexChat.Presence.Tracker`, if online broadcast `{:new_notice, %{sender: nickname, content: content, timestamp: DateTime.utc_now()}}` to `"user:#{target}"` topic, if not online show error "User not found: <target>". Sender sees nothing on success (fire-and-forget).

- [x] T016 [US1] Add `handle_info({:new_notice, payload}, socket)` clause in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Check ignore list with `IgnoreList.ignored?(session.ignore_list, sender, :notice)` — if ignored, return `{:noreply, socket}`. Otherwise create notice stream item via `notice_message/2` helper and insert into `:chat_messages` stream (default active-window routing). Do NOT call `maybe_highlight`, `maybe_play_highlight_sound`, or `maybe_capture_url`.

- [x] T017 [US1] Add `notice_message/2` private helper in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Returns `%{id: "notice-#{System.unique_integer([:positive])}", author: author, content: content, type: :notice, timestamp: DateTime.utc_now()}`. Place near existing `system_message/1` and `service_message/2` helpers.

- [x] T018 [US1] Add `:notice` type rendering clause in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex`. Add `render_message_body` clause matching `%{message: %{type: :notice}}` that renders: `<span class="chat-notice"><span class="chat-notice-nick">-{@message.author}-</span> <span class="chat-notice-content">{@message.content}</span></span>`. Place BEFORE the default `render_message_body` clause.

**Checkpoint**: User-to-user notices work end-to-end. Run notice tests: `mix test test/retro_hex_chat/commands/handlers/notice_test.exs test/retro_hex_chat_web/live/chat_live_notice_test.exs`. All should pass.

---

## Phase 4: User Story 2 - Send a Notice to a Channel (Priority: P1)

**Goal**: Users can send `/notice #channel <message>` and all channel members see the notice in the channel window with distinct formatting. Non-members are rejected.

**Independent Test**: A channel member sends a notice to a channel — all members see it in the channel window, non-members get an error.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T019 [P] [US2] Write LiveView tests for channel notice delivery in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notice_test.exs` (add to existing test file). Test: sending `/notice #test hello` when sender is a member broadcasts `%{event: "new_notice", payload: ...}` to `channel:#test` topic, sending `/notice #test hello` when sender is NOT a member shows error "You must be a member of #test to send notices there", receiving channel notice `%{event: "new_notice", payload: %{author: "Bob", content: "hey", channel: active_channel}}` renders notice with `-Bob-` prefix in chat stream, receiving channel notice from ignored user is silently dropped, channel notice does NOT trigger `play_sound` event. Tag with `@tag :liveview`.

### Implementation for User Story 2

- [x] T020 [US2] Extend `handle_dispatch_result` for `:notice` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` to handle channel-targeted notices. When target starts with `#`: check if channel is in `session.channels`, if yes broadcast `%{event: "new_notice", payload: %{author: session.nickname, content: content, channel: channel, timestamp: DateTime.utc_now()}}` to `"channel:#{channel}"` topic, if no show error "You must be a member of <channel> to send notices there". Pattern match the `"#" <> _ = channel` case BEFORE the user-notice case to ensure correct routing.

- [x] T021 [US2] Add `handle_info(%{event: "new_notice", payload: payload}, socket)` clause in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Check ignore list for `payload.author`. If not ignored and `payload.channel == session.active_channel`, insert `notice_message(payload.author, payload.content)` into `:chat_messages` stream. If channel is not active, the notice is received but not displayed (consistent with how channel messages work when viewing a different tab). No highlights, no sounds.

**Checkpoint**: Channel notices work end-to-end. Run all notice tests. Both US1 and US2 should pass independently.

---

## Phase 5: User Story 3 - Notice Routing Preferences (Priority: P2)

**Goal**: Users can configure where incoming user-targeted notices appear using `/notice_routing <active|status|sender>`. Preference is persisted for registered users.

**Independent Test**: Change routing preference and verify notices appear in the correct location (active window, status tab, or sender's PM window with fallback).

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T022 [P] [US3] Write unit tests for `/notice_routing` command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/notice_routing_test.exs`. Test: `execute([], ctx)` returns `{:ok, :ui_action, :notice_routing_show, %{}}`, `execute(["active"], ctx)` returns `{:ok, :ui_action, :notice_routing_set, %{routing: :active}}`, `execute(["status"], ctx)` returns correct result, `execute(["sender"], ctx)` returns correct result, `execute(["invalid"], ctx)` returns error with valid options list, `help/0` returns correct map. Tag with `@tag :unit`.

- [x] T023 [P] [US3] Write LiveView tests for notice routing behavior in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_notice_test.exs` (add to existing). Test: `:notice_routing_show` action displays current routing in status message, `:notice_routing_set` action updates session and shows confirmation, notice received with routing `:active` inserts into `:chat_messages` stream, notice received with routing `:status` and status tab open inserts into `:status_messages` stream, notice received with routing `:status` and no status tab falls back to `:chat_messages`, notice received with routing `:sender` and PM window open for sender inserts into `:chat_messages` when that PM is active, notice received with routing `:sender` and no PM window for sender falls back to `:chat_messages`, routing preference persisted for identified users (verify `NoticeRouting.save` called asynchronously). Tag with `@tag :liveview`.

### Implementation for User Story 3

- [x] T024 [P] [US3] Create `/notice_routing` command handler `RetroHexChat.Commands.Handlers.NoticeRouting` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/notice_routing.ex`. Implement `@behaviour RetroHexChat.Commands.Handler` with `validate/1` (always `:ok`), `execute/2` (dispatch to show/set/error based on args), `help/0`. Add `@spec` on all public functions.

- [x] T025 [US3] Add `handle_ui_action` clauses for `:notice_routing_show` and `:notice_routing_set` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. For `:notice_routing_show`: get current routing from session, display via `push_status_message`. For `:notice_routing_set`: update session with `Session.set_notice_routing`, if identified persist asynchronously with `Task.start(fn -> NoticeRouting.save(...) end)`, display confirmation via `push_status_message`.

- [x] T026 [US3] Extract `route_notice/4` private function in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Refactor the `handle_info({:new_notice, ...})` handler (from T016) to use this function. Implement routing logic: `:active` → `stream_insert(:chat_messages, notice)`, `:status` → if `show_status_tab` is true use `push_status_message` else fallback to active, `:sender` → if sender is in `session.pm_conversations` and `session.active_pm == sender` insert into `:chat_messages` else fallback to active.

- [x] T027 [US3] Add NoticeRouting preference loading to ChatLive mount/session-restoration flow in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. When a registered user connects and is identified, load their routing preference via `NoticeRouting.load/1` and update session with `Session.set_notice_routing/2`. Follow the pattern used for loading `perform_list`, `autojoin_list`, and other persisted preferences.

**Checkpoint**: Notice routing is fully configurable. Run all notice tests. US1, US2, and US3 should all pass independently.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, edge case handling, and final validation.

- [x] T028 [P] Add help topics to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`: (1) `/notice` command topic in "Commands" category with syntax, examples, and "See Also" linking to `/notice_routing` and "Notices" feature topic, (2) `/notice_routing` command topic in "Commands" category with syntax, examples, and "See Also" linking to `/notice`, (3) "Notices" feature topic in "Features" category explaining notice behavior, formatting, routing options, and negative constraints (no PM windows, no sounds, no auto-replies). Cross-reference from existing "Private Messages" and "Ignore System" topics.

- [x] T029 Add `Handler.result()` type union in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex` to include `{:ok, :notice, map()}` if not already covered by existing type. Ensure Dialyzer is satisfied with the new dispatch result pattern.

- [x] T030 Run full static analysis: `mix format --check-formatted && mix credo --strict && mix dialyzer`. Fix any warnings or errors. Ensure all new public functions have `@spec` annotations.

- [x] T031 Run full test suite: `make test`. Verify all existing tests still pass (no regressions). Verify all new notice tests pass. Confirm `mix test` completes in under 60 seconds.

- [x] T032 Run quickstart.md manual validation: start dev server with `make server`, perform the 10-step manual test flow documented in `specs/011-notice-system/quickstart.md`. Verify all steps pass.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion (migration, schema, Session struct) — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion
- **User Story 2 (Phase 4)**: Depends on Phase 2 completion. Can run in parallel with US1, but US1 is recommended first since T015/T017 create the `handle_dispatch_result` and `notice_message/2` that US2 extends.
- **User Story 3 (Phase 5)**: Depends on Phase 2 completion. Depends on US1 (T016 creates `handle_info` that US3's T026 refactors).
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2. No dependencies on other stories. **MVP target.**
- **US2 (P1)**: Can start after Phase 2. Extends US1's dispatch handler (T015). Recommended after US1.
- **US3 (P2)**: Can start after Phase 2. Refactors US1's receive handler (T016). Recommended after US1.

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Handler before ChatLive integration
- ChatLive dispatch before ChatLive receive
- Component rendering alongside or after ChatLive

### Parallel Opportunities

- **Phase 1**: T002, T003, T004, T005, T006 can all run in parallel (different files)
- **Phase 2 Tests**: T007, T008, T009, T010 can all run in parallel (different files/describe blocks)
- **US1 Tests**: T012, T013 can run in parallel
- **US1 Implementation**: T014, T018 can run in parallel with each other (handler + component are independent files)
- **US3 Tests**: T022, T023 can run in parallel
- **Phase 6**: T028, T029 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch tests in parallel (write first, must FAIL):
Task: T012 "Unit tests for /notice handler in notice_test.exs"
Task: T013 "LiveView tests for user notice delivery in chat_live_notice_test.exs"

# Launch handler + component in parallel (different files):
Task: T014 "Create /notice command handler in handlers/notice.ex"
Task: T018 "Add :notice rendering in chat_message.ex"

# Then sequential (same file - chat_live.ex):
Task: T015 "Add handle_dispatch_result for :notice in chat_live.ex"
Task: T016 "Add handle_info for :new_notice in chat_live.ex"
Task: T017 "Add notice_message/2 helper in chat_live.ex"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T006)
2. Complete Phase 2: Foundational (T007-T011)
3. Complete Phase 3: User Story 1 (T012-T018)
4. **STOP and VALIDATE**: Run tests, verify user-to-user notices work
5. Deploy/demo if ready — users can already send notices

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy (MVP — user notices work!)
3. Add User Story 2 → Test independently → Deploy (channel notices added!)
4. Add User Story 3 → Test independently → Deploy (routing preferences added!)
5. Add Polish → Final validation → Feature complete

### Recommended Execution Order (Single Developer)

Phase 1 → Phase 2 → US1 → US2 → US3 → Polish

Total: 32 tasks, estimated 6 phases.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Tests MUST fail before implementation (TDD per Constitution Principle IV)
- No new dependencies needed — all tools already in mix.lock
- No new GenServers — notices are fire-and-forget via PubSub
- Notice messages are transient (no DB persistence for message content)
- Only the routing preference is persisted (1 new table)
