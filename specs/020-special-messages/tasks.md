# Tasks: Special Messages

**Input**: Design documents from `/specs/020-special-messages/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — the project constitution (Principle IV) mandates TDD.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configuration, database migrations, and shared modules that all user stories depend on

- [X]T001 Add `:admins` and `:server_operators` config keys to `config/config.exs` (empty lists), `config/dev.exs` (test values), and `config/test.exs` (test values)
- [X]T002 Create migration for `server_settings` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_server_settings.exs` per data-model.md
- [X]T003 Create migration for `channel_welcome_messages` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_channel_welcome_messages.exs` per data-model.md
- [X]T004 Run migrations with `mix ecto.migrate`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain modules that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation

- [X]T005 [P] Write unit tests for `Accounts.ServerRoles` in `apps/retro_hex_chat/test/retro_hex_chat/accounts/server_roles_test.exs` — test `admin?/2` (identified+in-list=true, not-identified=false, not-in-list=false), `server_operator?/2` (same pattern), `admin_list/0`, `server_operator_list/0`
- [X]T006 [P] Write unit tests for `Accounts.Session` new fields in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs` — test `has_mode?/2`, `set_mode/2`, `unset_mode/2`, `add_welcomed_channel/2`, `welcomed_channel?/2`, default values for `user_modes` and `welcomed_channels`
- [X]T007 [P] Write unit tests for `Services.ServerSetting` schema in `apps/retro_hex_chat/test/retro_hex_chat/services/server_setting_test.exs` — test changeset validations (key required, max lengths)
- [X]T008 [P] Write unit tests for `Services.ChannelWelcomeMessage` schema in `apps/retro_hex_chat/test/retro_hex_chat/services/channel_welcome_message_test.exs` — test changeset validations (channel_name required, message required, set_by required, unique constraint)

### Implementation for Foundation

- [X]T009 [P] Create `Accounts.ServerRoles` module in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/server_roles.ex` — implement `admin?/2`, `server_operator?/2`, `admin_list/0`, `server_operator_list/0` reading from Application config, per contracts/domain-api.md
- [X]T010 [P] Extend `Accounts.Session` struct in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` — add `user_modes: MapSet.new()` and `welcomed_channels: MapSet.new()` fields, implement `has_mode?/2`, `set_mode/2`, `unset_mode/2`, `add_welcomed_channel/2`, `welcomed_channel?/2` per contracts/domain-api.md
- [X]T011 [P] Create `Services.ServerSetting` Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/services/server_setting.ex` — fields: key (string), value (text), updated_by (string), timestamps; changeset with validations per data-model.md
- [X]T012 [P] Create `Services.ChannelWelcomeMessage` Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/services/channel_welcome_message.ex` — fields: channel_name (string), message (text), set_by (string), timestamps; changeset with validations per data-model.md
- [X]T013 Extend `Services.Queries` in `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex` — add `get_setting/1`, `upsert_setting/3`, `delete_setting/1`, `get_welcome_message/1`, `upsert_welcome_message/3`, `delete_welcome_message/1` per contracts/domain-api.md
- [X]T014 Modify `Commands.Handler` context type in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex` — add `is_admin: boolean()` and `is_server_operator: boolean()` to `@type context`

**Checkpoint**: Foundation ready — all schemas, queries, roles, session helpers, and context type in place. User story implementation can begin.

---

## Phase 3: User Story 1 — Message of the Day (MOTD) (Priority: P1) MVP

**Goal**: Administrators can set/clear the MOTD; users see it on connect and can re-read it with `/motd`.

**Independent Test**: Set a MOTD via `/setmotd`, connect a user, verify MOTD appears in Status Window. Type `/motd` to re-read. Clear with `/clearmotd`, reconnect, verify no MOTD.

### Tests for User Story 1

- [X]T015 [P] [US1] Write unit tests for `Services.Motd` in `apps/retro_hex_chat/test/retro_hex_chat/services/motd_test.exs` — test `get/0` (returns nil when unset, returns text when set), `set/2` (persists to DB, updates cache, broadcasts), `clear/1` (removes from DB, clears cache, broadcasts)
- [X]T016 [P] [US1] Write unit tests for `/setmotd` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/set_motd_test.exs` — test admin permission check, non-admin rejected, valid MOTD set, empty args error, help/0 and validate/1
- [X]T017 [P] [US1] Write unit tests for `/clearmotd` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/clear_motd_test.exs` — test admin permission check, non-admin rejected, successful clear, help/0 and validate/1
- [X]T018 [P] [US1] Write unit tests for `/motd` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/motd_test.exs` — test returns ui_action with content when MOTD set, returns system message when no MOTD, any user can execute, help/0 and validate/1

### Implementation for User Story 1

- [X]T019 [US1] Create `Services.Motd` module in `apps/retro_hex_chat/lib/retro_hex_chat/services/motd.ex` — implement `get/0` (cached read), `set/2` (DB + cache + PubSub broadcast to "server:settings"), `clear/1` (DB + cache + PubSub broadcast), `init_cache/0` (load from DB on app start) per contracts/domain-api.md
- [X]T020 [P] [US1] Create `/setmotd` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/set_motd.ex` — implement Handler behaviour; require `context.is_admin`, call `Motd.set/2`, return `{:ok, :system, %{content: "MOTD has been updated."}}` per contracts/domain-api.md
- [X]T021 [P] [US1] Create `/clearmotd` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/clear_motd.ex` — implement Handler behaviour; require `context.is_admin`, call `Motd.clear/1`, return `{:ok, :system, %{content: "MOTD has been cleared."}}` per contracts/domain-api.md
- [X]T022 [P] [US1] Create `/motd` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/motd.ex` — implement Handler behaviour; no permission required, call `Motd.get/0`, return `{:ok, :ui_action, :show_motd, %{content: content}}` or system message if nil per contracts/domain-api.md
- [X]T023 [US1] Register `"setmotd"`, `"clearmotd"`, `"motd"` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X]T024 [US1] Modify `CommandDispatch` context builder in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` — add `is_admin: ServerRoles.admin?(session.nickname, session.identified)` and `is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)` to the context map
- [X]T025 [US1] Create `UiActions.ServerMessages` module in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/server_messages.ex` — implement `handle_ui_action/3` for `:show_motd` action (push MOTD to status_messages stream with `:motd` type) per contracts/web-layer.md
- [X]T026 [US1] Modify `UiActionHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_action_handlers.ex` — add routing for `:show_motd` to `UiActions.ServerMessages`
- [X]T027 [US1] Create `PubSubHandlers.ServerMessages` module in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/server_messages.ex` — implement `handle_info/2` for `{:motd_updated, _}` (cache sync in socket assigns) per contracts/web-layer.md
- [X]T028 [US1] Modify `PubSubHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex` — add routing for `{:motd_updated, _}` to `ServerMessages`
- [X]T029 [US1] Modify `ChatLive.mount/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — subscribe to `"server:settings"` PubSub topic; after session init, call `Motd.get/0` and if set, push_status_message with `:motd` type
- [X]T030 [US1] Add CSS styles for MOTD in the appropriate CSS file under `apps/retro_hex_chat_web/assets/css/` — bordered container with header "Message of the Day" per contracts/web-layer.md

**Checkpoint**: MOTD fully functional — admin can set/clear, users see on connect and via /motd. Test independently.

---

## Phase 4: User Story 2 — Channel Welcome Message (Priority: P2)

**Goal**: Channel operators can set/clear welcome messages; users see them on first join per session.

**Independent Test**: Set a welcome message on a channel via `/setwelcome`, have a different user join, verify they see the welcome. Part and rejoin — verify no duplicate. Verify the setter doesn't see it.

### Tests for User Story 2

- [X]T031 [P] [US2] Write unit tests for `Channels.Server` welcome message functions in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs` — test `set_welcome/3`, `clear_welcome/2`, `get_welcome/1`, welcome message loaded on init from DB
- [X]T032 [P] [US2] Write unit tests for `/setwelcome` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/set_welcome_test.exs` — test operator permission check, non-operator rejected, no channel error, valid welcome set, empty args treated as clear, help/0 and validate/1
- [X]T033 [P] [US2] Write unit tests for `/clearwelcome` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/clear_welcome_test.exs` — test operator permission check, non-operator rejected, no channel error, successful clear, help/0 and validate/1

### Implementation for User Story 2

- [X]T034 [US2] Modify `Channels.Server` in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — add `welcome_message` field to state, load from DB on init via `Queries.get_welcome_message/1`, implement `set_welcome/3` (GenServer call → update state + DB + broadcast), `clear_welcome/2` (GenServer call → clear state + DB + broadcast), `get_welcome/1` (GenServer call → return cached welcome) per contracts/domain-api.md
- [X]T035 [P] [US2] Create `/setwelcome` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/set_welcome.ex` — implement Handler behaviour; require channel operator/owner, return `{:ok, :ui_action, :set_welcome, %{channel: channel, message: message}}`, treat empty message as clear per contracts/domain-api.md
- [X]T036 [P] [US2] Create `/clearwelcome` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/clear_welcome.ex` — implement Handler behaviour; require channel operator/owner, return `{:ok, :ui_action, :clear_welcome, %{channel: channel}}` per contracts/domain-api.md
- [X]T037 [US2] Register `"setwelcome"` and `"clearwelcome"` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X]T038 [US2] Extend `UiActions.ServerMessages` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/server_messages.ex` — add `handle_ui_action/3` for `:set_welcome` (call `Server.set_welcome/3`, push confirmation) and `:clear_welcome` (call `Server.clear_welcome/2`, push confirmation)
- [X]T039 [US2] Modify `UiActionHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_action_handlers.ex` — add routing for `:set_welcome` and `:clear_welcome` to `UiActions.ServerMessages`
- [X]T040 [US2] Modify channel join flow in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex` — after successful `Server.join`, call `Server.get_welcome/1`; if welcome exists AND user != set_by AND `!Session.welcomed_channel?(session, channel)`, insert welcome as system message in channel stream and call `Session.add_welcomed_channel/2` per contracts/web-layer.md
- [X]T041 [US2] Extend `PubSubHandlers.ServerMessages` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/server_messages.ex` — add handler for `{:welcome_changed, _}` (display confirmation to channel operators)
- [X]T042 [US2] Modify `PubSubHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex` — add routing for `{:welcome_changed, _}` to `ServerMessages`

**Checkpoint**: Channel welcome messages fully functional — operators can set/clear, joiners see welcome once per session. Test independently.

---

## Phase 5: User Story 3 — Wallops (Priority: P3)

**Goal**: Server operators can broadcast to users with +w mode; users can toggle +w via `/umode`.

**Independent Test**: Enable +w with `/umode +w`, have an operator send `/wallops test`, verify message appears in Status Window. Disable +w, send another wallops, verify it's not shown.

### Tests for User Story 3

- [X]T043 [P] [US3] Write unit tests for `/umode` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/umode_test.exs` — test +w enables wallops mode, -w disables, unknown mode error, invalid format error, help/0 and validate/1
- [X]T044 [P] [US3] Write unit tests for `/wallops` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/wallops_test.exs` — test server operator permission check (and admin allowed), non-operator rejected, valid wallops broadcasts to "server:wallops", empty args error, help/0 and validate/1

### Implementation for User Story 3

- [X]T045 [P] [US3] Create `/umode` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/umode.ex` — implement Handler behaviour; parse mode string (+w/-w), return `{:ok, :ui_action, :set_user_mode, %{mode_string: mode_string}}`, reject unknown modes per contracts/domain-api.md
- [X]T046 [P] [US3] Create `/wallops` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/wallops.ex` — implement Handler behaviour; require `context.is_server_operator || context.is_admin`, broadcast `{:wallops, %{sender, content, timestamp}}` to "server:wallops", return `{:ok, :system, %{content: "Wallops sent."}}` per contracts/domain-api.md
- [X]T047 [US3] Register `"umode"` and `"wallops"` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X]T048 [US3] Extend `UiActions.ServerMessages` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/server_messages.ex` — add `handle_ui_action/3` for `:set_user_mode` (parse mode string, update session via `Session.set_mode/2` or `Session.unset_mode/2`, push confirmation to Status Window)
- [X]T049 [US3] Modify `UiActionHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_action_handlers.ex` — add routing for `:set_user_mode` to `UiActions.ServerMessages`
- [X]T050 [US3] Extend `PubSubHandlers.ServerMessages` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/server_messages.ex` — add handler for `{:wallops, _}` (check `Session.has_mode?(session, :wallops)`, if true push `[Wallops] sender: content` to Status Window, else noop)
- [X]T051 [US3] Modify `PubSubHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex` — add routing for `{:wallops, _}` to `ServerMessages`
- [X]T052 [US3] Modify `ChatLive.mount/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — subscribe to `"server:wallops"` PubSub topic
- [X]T053 [US3] Add CSS styles for wallops messages in the appropriate CSS file under `apps/retro_hex_chat_web/assets/css/` — italic text with highlight color per contracts/web-layer.md

**Checkpoint**: Wallops fully functional — operators can send, +w users receive in Status Window. Test independently.

---

## Phase 6: User Story 4 — Global Announcement (Priority: P4)

**Goal**: Administrators can broadcast announcements to all connected users, bypassing ignore lists.

**Independent Test**: Have an admin send `/announce test`, verify every connected user sees it in their active window with bold + colored styling. Verify it bypasses ignore lists.

### Tests for User Story 4

- [X]T054 [P] [US4] Write unit tests for `/announce` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/announce_test.exs` — test admin permission check, non-admin rejected, valid announcement broadcasts to "server:announcements", empty args error, help/0 and validate/1

### Implementation for User Story 4

- [X]T055 [US4] Create `/announce` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/announce.ex` — implement Handler behaviour; require `context.is_admin`, broadcast `{:announcement, %{sender, content, timestamp}}` to "server:announcements", return `{:ok, :system, %{content: "Announcement sent to all users."}}` per contracts/domain-api.md
- [X]T056 [US4] Register `"announce"` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X]T057 [US4] Extend `PubSubHandlers.ServerMessages` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/server_messages.ex` — add handler for `{:announcement, _}` (insert `[ANNOUNCEMENT] content` into active window's message stream with `:announcement` type, NO ignore list check) per contracts/web-layer.md
- [X]T058 [US4] Modify `PubSubHandlers` router in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex` — add routing for `{:announcement, _}` to `ServerMessages`
- [X]T059 [US4] Modify `ChatLive.mount/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — subscribe to `"server:announcements"` PubSub topic
- [X]T060 [US4] Add CSS styles for announcement messages in the appropriate CSS file under `apps/retro_hex_chat_web/assets/css/` — bold text, amber/yellow colored background, white text per contracts/web-layer.md

**Checkpoint**: Global announcements fully functional — admin can send, all users see in active window. Test independently.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help system, integration tests, and final validation

- [X]T061 [P] Create help topics module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/special_messages.ex` — add 9 help topics: /motd, /setmotd, /clearmotd, /setwelcome, /clearwelcome, /wallops, /announce, /umode, and "Special Messages" feature overview with See Also cross-references per CLAUDE.md Help System requirements
- [X]T062 [P] Update the commands overview help topic to include the 8 new commands in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` (or the relevant submodule)
- [X]T063 [P] Write LiveView integration/e2e tests in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/special_messages_test.exs` — test MOTD display on connect, /motd command, welcome message on join (shown once, not to setter), wallops delivery with +w filter, announcement delivery bypassing ignore list
- [X]T064 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migrations must run first) — BLOCKS all user stories
- **US1 — MOTD (Phase 3)**: Depends on Phase 2 — can start immediately after foundation
- **US2 — Welcome (Phase 4)**: Depends on Phase 2 — can start in parallel with US1 (independent files)
- **US3 — Wallops (Phase 5)**: Depends on Phase 2 — can start in parallel with US1/US2 (independent files). Note: shares Session user_modes with US3 but Session extension is in Phase 2.
- **US4 — Announcement (Phase 6)**: Depends on Phase 2 — can start in parallel with US1/US2/US3
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Independent — only needs foundation. Creates MOTD service, 3 command handlers, PubSub handler, UI action handler.
- **US2 (P2)**: Independent — only needs foundation. Creates 2 command handlers, extends Channel.Server, modifies join flow.
- **US3 (P3)**: Independent — only needs foundation. Creates 2 command handlers, uses Session.user_modes from foundation.
- **US4 (P4)**: Independent — only needs foundation. Creates 1 command handler, 1 PubSub handler.

### Within Each User Story

1. Tests written FIRST (TDD — Principle IV)
2. Domain modules before web layer
3. Command handlers before registry registration
4. UI action handlers before router updates
5. PubSub handlers before mount subscriptions

### Parallel Opportunities

- **Phase 2**: T005–T008 (tests) all parallel; T009–T012 (implementations) all parallel
- **Phase 3**: T015–T018 (tests) all parallel; T020–T022 (handlers) all parallel
- **Phase 4**: T031–T033 (tests) all parallel; T035–T036 (handlers) parallel
- **Phase 5**: T043–T044 (tests) parallel; T045–T046 (handlers) parallel
- **Phase 7**: T061–T063 all parallel

---

## Parallel Example: Foundation Phase

```bash
# Launch all foundation tests together:
Task: "Unit tests for ServerRoles" (T005)
Task: "Unit tests for Session new fields" (T006)
Task: "Unit tests for ServerSetting schema" (T007)
Task: "Unit tests for ChannelWelcomeMessage schema" (T008)

# Then launch all foundation implementations together:
Task: "Create ServerRoles module" (T009)
Task: "Extend Session struct" (T010)
Task: "Create ServerSetting schema" (T011)
Task: "Create ChannelWelcomeMessage schema" (T012)
```

## Parallel Example: User Story 1 (MOTD)

```bash
# Launch all US1 tests together:
Task: "Unit tests for Motd service" (T015)
Task: "Unit tests for /setmotd handler" (T016)
Task: "Unit tests for /clearmotd handler" (T017)
Task: "Unit tests for /motd handler" (T018)

# Then launch parallelizable handlers:
Task: "Create /setmotd handler" (T020)
Task: "Create /clearmotd handler" (T021)
Task: "Create /motd handler" (T022)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (config + migrations)
2. Complete Phase 2: Foundation (roles, session, schemas, queries, handler context)
3. Complete Phase 3: User Story 1 — MOTD
4. **STOP and VALIDATE**: Admin can set/clear MOTD, users see it on connect and via /motd
5. Deploy/demo if ready — MOTD alone delivers value

### Incremental Delivery

1. Setup + Foundation → Core infrastructure ready
2. Add US1 (MOTD) → Test independently → Deploy (MVP)
3. Add US2 (Welcome) → Test independently → Deploy
4. Add US3 (Wallops) → Test independently → Deploy
5. Add US4 (Announcement) → Test independently → Deploy
6. Polish phase → Help topics, integration tests, CI validation

### Parallel Strategy

With full parallelization after Phase 2:
- US1 (MOTD): 16 tasks
- US2 (Welcome): 12 tasks
- US3 (Wallops): 11 tasks
- US4 (Announcement): 7 tasks
All four can proceed simultaneously as they touch different files.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- TDD is mandatory (Constitution Principle IV): write tests first, verify they fail, then implement
- All 8 command handlers implement the existing Handler behaviour (@callback execute, validate, help)
- Total tasks: 64 (4 setup + 10 foundation + 16 US1 + 12 US2 + 11 US3 + 7 US4 + 4 polish)
- Suggested MVP scope: Phase 1 + Phase 2 + Phase 3 (US1 — MOTD only)
