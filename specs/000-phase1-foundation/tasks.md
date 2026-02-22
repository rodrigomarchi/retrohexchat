# Tasks: RetroHexChat Phase 1 — Foundation & Core Chat

**Input**: Design documents from `/specs/001-phase1-foundation/`
**Prerequisites**: plan.md, spec.md, data-model.md, research.md, quickstart.md, contracts/commands.md, contracts/services.md

**Tests**: TDD is non-negotiable (Constitution IV). Every implementation task is preceded by its test. Tests MUST be written first and MUST FAIL before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain app**: `apps/retro_hex_chat/lib/retro_hex_chat/` (bounded contexts)
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web app**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **Web tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`
- **Migrations**: `apps/retro_hex_chat/priv/repo/migrations/`
- **Assets**: `apps/retro_hex_chat_web/assets/`
- **Test support**: `apps/retro_hex_chat/test/support/`, `apps/retro_hex_chat_web/test/support/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Phoenix umbrella scaffold, dependencies, tooling, and CI foundation

- [x] T001 Generate Phoenix umbrella project with `mix phx.new retro_hex_chat --umbrella --live --database postgres` and verify it compiles
- [x] T002 Add project dependencies to `apps/retro_hex_chat/mix.exs`: `bcrypt_elixir`, `mox`, `ex_machina`, `stream_data`; and to `apps/retro_hex_chat_web/mix.exs`: `floki`; then run `mix deps.get`
- [x] T003 [P] Configure Credo with strict rules in `.credo.exs` at umbrella root
- [x] T004 [P] Configure Dialyxir in umbrella root `mix.exs` with `plt_add_apps` for Phoenix and Ecto
- [x] T005 [P] Install retro design system via npm in `apps/retro_hex_chat_web/assets/package.json` and configure esbuild to bundle it
- [x] T006 [P] Configure ExUnit with tags (`:unit`, `:integration`, `:liveview`) in `apps/retro_hex_chat/test/test_helper.exs` and `apps/retro_hex_chat_web/test/test_helper.exs`; configure async Ecto sandbox
- [x] T007 [P] Create test support files: `apps/retro_hex_chat/test/support/factory.ex` (ExMachina), `apps/retro_hex_chat/test/support/mocks.ex` (Mox definitions for Handler behaviour and service behaviours)
- [x] T008 [P] Configure bcrypt reduced rounds (log_rounds: 4) for test environment in `apps/retro_hex_chat/config/test.exs`
- [x] T009 Verify `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict` all pass on the empty project

**Checkpoint**: Clean umbrella project with all tooling configured. `mix test` passes (no tests yet). Static analysis passes.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Database migrations, Ecto schemas, OTP supervision tree, PubSub, Presence, and core bounded context skeletons that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

### Database & Schemas

- [x] T010 Create migration `create_messages` with columns and indexes per data-model.md in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T011 [P] Create migration `create_private_messages` with columns and indexes (including least/greatest composite) per data-model.md in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T012 [P] Create migration `create_registered_nicks` with columns and unique index per data-model.md in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T013 [P] Create migration `create_registered_channels` with columns and unique index per data-model.md in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T014 [P] Create migration `create_access_list_entries` with columns and composite indexes per data-model.md in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T015 [P] Create migration `create_bans` with columns and indexes per data-model.md in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T016 Create migration `enable_pg_trgm` to enable the pg_trgm PostgreSQL extension in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T017 Run `mix ecto.migrate` and verify all 7 migrations succeed

### Ecto Schemas (with tests)

- [x] T018 [P] Write tests for Message schema (changeset validation, type enum) in `apps/retro_hex_chat/test/retro_hex_chat/chat/message_test.exs`
- [x] T019 [P] Write tests for PrivateMessage schema (changeset validation) in `apps/retro_hex_chat/test/retro_hex_chat/chat/private_message_test.exs`
- [x] T020 [P] Write tests for RegisteredNick schema (changeset, password hashing) in `apps/retro_hex_chat/test/retro_hex_chat/services/registered_nick_test.exs`
- [x] T021 [P] Write tests for RegisteredChannel schema (changeset, mode parsing) in `apps/retro_hex_chat/test/retro_hex_chat/services/registered_channel_test.exs`
- [x] T022 [P] Write tests for AccessListEntry schema (changeset, level enum) in `apps/retro_hex_chat/test/retro_hex_chat/services/access_list_entry_test.exs`
- [x] T023 [P] Write tests for Ban schema (changeset validation) in `apps/retro_hex_chat/test/retro_hex_chat/services/ban_test.exs`
- [x] T024 [P] Implement Message schema in `apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex`
- [x] T025 [P] Implement PrivateMessage schema in `apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex`
- [x] T026 [P] Implement RegisteredNick schema with bcrypt password hashing in `apps/retro_hex_chat/lib/retro_hex_chat/services/registered_nick.ex`
- [x] T027 [P] Implement RegisteredChannel schema in `apps/retro_hex_chat/lib/retro_hex_chat/services/registered_channel.ex`
- [x] T028 [P] Implement AccessListEntry schema with level enum constraint in `apps/retro_hex_chat/lib/retro_hex_chat/services/access_list_entry.ex`
- [x] T029 [P] Implement Ban schema in `apps/retro_hex_chat/lib/retro_hex_chat/services/ban.ex`
- [x] T030 Update ExMachina factory with factories for all 6 schemas in `apps/retro_hex_chat/test/support/factory.ex`

### OTP Supervision Tree

- [x] T031 Write tests for Channels.Supervisor (start_child, stop_child) in `apps/retro_hex_chat/test/retro_hex_chat/channels/supervisor_test.exs`
- [x] T032 Implement Channels.Supervisor (DynamicSupervisor) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/supervisor.ex`
- [x] T033 [P] Implement Channels.Registry helpers (via_tuple, lookup) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/registry.ex`
- [x] T034 Add Channels.Supervisor and Registry to the domain app supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`

### Core Bounded Context Skeletons

- [x] T035 [P] Write tests for Accounts.NicknameValidator (valid/invalid nicknames per FR-002) in `apps/retro_hex_chat/test/retro_hex_chat/accounts/nickname_validator_test.exs`
- [x] T036 [P] Write tests for Accounts.Session struct (new, update_nickname, add_channel, etc.) in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`
- [x] T037 [P] Implement Accounts.NicknameValidator (max 16 chars, starts with letter, no spaces, IRC rules) in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/nickname_validator.ex`
- [x] T038 [P] Implement Accounts.Session struct in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [x] T039 [P] Implement Accounts.Policy (identity checks) in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/policy.ex`
- [x] T040 [P] Implement Accounts.Events (Telemetry: connected, disconnected, nick_changed) in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/events.ex`
- [x] T041 [P] Write tests for RateLimit.Limiter (check_rate, muted?, reset) in `apps/retro_hex_chat/test/retro_hex_chat/rate_limit/limiter_test.exs`
- [x] T042 [P] Implement RateLimit.Limiter (ETS token bucket: 5 msg/sec, 2 cmd/sec, mute state) in `apps/retro_hex_chat/lib/retro_hex_chat/rate_limit/limiter.ex`
- [x] T043 [P] Implement RateLimit.Events (Telemetry: rate_limited) in `apps/retro_hex_chat/lib/retro_hex_chat/rate_limit/events.ex`
- [x] T044 Add RateLimit ETS table creation to domain app supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- [x] T045 [P] Write tests for Presence.Tracker (track, untrack, list, update_away) in `apps/retro_hex_chat/test/retro_hex_chat/presence/tracker_test.exs`
- [x] T046 [P] Implement Presence.Tracker and Presence.Events (track/untrack/list/update_away + Telemetry: user_online, user_offline, user_away) in `apps/retro_hex_chat/lib/retro_hex_chat/presence/tracker.ex` and `apps/retro_hex_chat/lib/retro_hex_chat/presence/events.ex`
- [x] T047 [P] Write tests for Commands.Parser (parse "/cmd args" and plain messages, StreamData property tests) in `apps/retro_hex_chat/test/retro_hex_chat/commands/parser_test.exs`
- [x] T048 [P] Implement Commands.Parser in `apps/retro_hex_chat/lib/retro_hex_chat/commands/parser.ex`
- [x] T049 Implement Commands.Handler behaviour definition in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex`
- [x] T050 [P] Implement Commands.Registry (command name → module mapping for all 18+1 commands) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [x] T051 [P] Write tests for Commands.Dispatcher (lookup, validate, execute flow) in `apps/retro_hex_chat/test/retro_hex_chat/commands/dispatcher_test.exs`
- [x] T052 Implement Commands.Dispatcher in `apps/retro_hex_chat/lib/retro_hex_chat/commands/dispatcher.ex`
- [x] T053 [P] Implement Commands.Policy (pre-dispatch rate limit and permission checks) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/policy.ex`
- [x] T054 [P] Implement Commands.Events (Telemetry: command_executed) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/events.ex`
- [x] T055 Verify `mix test` passes, `mix format --check-formatted`, `mix credo --strict` all green

**Checkpoint**: Foundation ready — all migrations run, schemas pass validation, OTP tree starts, command parser/dispatcher wired, rate limiter works. User story implementation can now begin.

---

## Phase 3: User Story 1 — Connect and Chat in #lobby (Priority: P1) MVP

**Goal**: User connects via retro dialog, auto-joins #lobby, exchanges messages in real time with full MDI layout

**Independent Test**: Open two browser tabs, connect with different nicknames, exchange messages in #lobby. Verify layout (treebar, chat, nicklist, status bar), message format `[HH:MM] <nick> msg`, system messages for joins, and /me actions.

**FRs covered**: FR-001 through FR-009, FR-014, FR-017 through FR-023, FR-027, FR-069 through FR-076

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T056 [P] [US1] Write tests for Channels.Server GenServer (start, join, part, send_message, get_state, membership tracking) in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`
- [x] T057 [P] [US1] Write tests for Channels.Membership struct (add, remove, role helpers) in `apps/retro_hex_chat/test/retro_hex_chat/channels/membership_test.exs`
- [x] T058 [P] [US1] Write tests for Chat.Service (send_message, persist, broadcast orchestration) in `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
- [x] T059 [P] [US1] Write tests for Chat.Policy (content length validation, rate limit gate, moderated check) in `apps/retro_hex_chat/test/retro_hex_chat/chat/policy_test.exs`
- [x] T060 [P] [US1] Write tests for Chat.Queries (insert message, cursor pagination with 50-message pages) in `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs`
- [x] T061 [P] [US1] Write LiveView test for ConnectLive (renders dialog, validates nickname, connects) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/connect_live_test.exs`
- [x] T062 [P] [US1] Write LiveView test for ChatLive (renders MDI layout, receives messages via PubSub, sends messages) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`

### Implementation for User Story 1

#### Domain Layer

- [x] T063 [P] [US1] Implement Channels.Membership struct (members map with role + joined_at, add/remove/role helpers) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/membership.ex`
- [x] T064 [P] [US1] Implement Channels.Modes struct (mode map, parse mode string, check enforcement) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/modes.ex`
- [x] T065 [P] [US1] Implement Channels.Policy (join permissions, mode enforcement, operator checks) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/policy.ex`
- [x] T066 [P] [US1] Implement Channels.Events (Telemetry: channel_created, destroyed, mode_changed, topic_changed) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/events.ex`
- [x] T067 [US1] Implement Channels.Server GenServer (init with state struct, join/part/send_message/get_state calls, PubSub broadcasts, membership tracking, creator-becomes-operator) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [x] T068 [P] [US1] Implement Chat.Policy (content length <=1000, rate limit check via RateLimit.Limiter, moderated channel check) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/policy.ex`
- [x] T069 [P] [US1] Implement Chat.Queries (insert_message, list_messages with cursor pagination, initial 50 messages) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex`
- [x] T070 [US1] Implement Chat.Service (send_message orchestration: policy check → persist → PubSub broadcast) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [x] T071 [P] [US1] Implement Chat.Events (Telemetry: message_sent, message_persisted) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/events.ex`

#### Web Layer — Components

- [x] T072 [P] [US1] Implement Window component (retro window wrapper with title bar, borders) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/window.ex`
- [x] T073 [P] [US1] Implement TitleBar component (gradient title bar with window controls) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/title_bar.ex`
- [x] T074 [P] [US1] Implement StatusBar component (nickname, active channel, user count, connection status) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_bar.ex`
- [x] T075 [P] [US1] Implement MenuBar component (File, Edit, View, Help dropdowns — structure only, handlers in US12) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex`
- [x] T076 [P] [US1] Implement Toolbar component (Connect/Disconnect, Channel List, Settings buttons — structure only) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toolbar.ex`
- [x] T077 [P] [US1] Implement Treebar component (Services/Channels/Private sections, active highlight, unread bold) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex`
- [x] T078 [P] [US1] Implement Nicklist component (users grouped by role @/+/regular, sorted alphabetically, user count) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex`
- [x] T079 [P] [US1] Implement ChatMessage component (message rendering: timestamp [HH:MM], color-coded nicknames from 12-color palette, type-based styling: gray-blue system, gold service, red error, purple action) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex`

#### Web Layer — CSS

- [x] T080 [P] [US1] Create dark theme CSS with custom properties overlay (windows #1a1a2e, chat #0d0d1a, text #c0c0c0, 3D borders, monospace fonts) in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T081 [P] [US1] Create main CSS entry importing retro design system and dark-theme.css, with layout grid for MDI (treebar | chat+input | nicklist) in `apps/retro_hex_chat_web/assets/css/app.css`

#### Web Layer — LiveViews

- [x] T082 [US1] Implement ConnectLive (retro connection dialog: nickname/alt-nickname fields, real-time validation via NicknameValidator, uniqueness check via Presence, connect button, Guest_XXXXX fallback) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/connect_live.ex`
- [x] T083 [US1] Implement ChatLive (main MDI layout: mount with session assigns, auto-join #lobby, subscribe to PubSub "channel:#lobby" and "user:#{nickname}", render components: treebar, chat area with LiveView streams, nicklist, status bar, input field; handle_event for send_input delegating to Parser → message or command; handle_info for PubSub messages rendering into stream; terminate/2 for disconnect cleanup per services.md contract) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T084 [US1] Configure router: ConnectLive at "/", ChatLive at "/chat" (with session plug) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/router.ex`
- [x] T085 [US1] Update root/app layouts in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts.ex` to apply dark theme class and load retro design system

#### Seed Data

- [x] T086 [US1] Create seeds file to ensure #lobby channel exists on startup in `apps/retro_hex_chat/priv/repo/seeds.exs`

- [x] T087 [US1] Run full test suite and verify all US1 tests pass: `mix test --only unit && mix test --only integration && mix test --only liveview`

**Checkpoint**: US1 complete — two users can connect, chat in #lobby in real time with full retro MDI layout. Core value delivered.

---

## Phase 4: User Story 2 — Channels: Create, Join, Part (Priority: P2)

**Goal**: Users can create/join/part channels via /join and /part, channels appear in treebar, operator badge, unread indicators, /list dialog

**Independent Test**: One user creates #elixir, another joins, they exchange messages, one leaves. Verify treebar updates, @ badge, channel destruction when empty.

**FRs covered**: FR-010 through FR-016, FR-033 (Handler behaviour — /join, /part, /list)

### Tests for User Story 2

- [x] T088 [P] [US2] Write tests for Handlers.Join (create channel, join existing, password channel, errors: invalid name, full, banned, limit reached) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/join_test.exs`
- [x] T089 [P] [US2] Write tests for Handlers.Part (part with message, part active channel, part last-user-destroys-channel) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/part_test.exs`
- [x] T090 [P] [US2] Write tests for Handlers.List (returns channel list data) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/list_test.exs`
- [x] T091 [P] [US2] Write LiveView test for ChannelListLive (renders channel list dialog with search/filter) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_live_test.exs`

### Implementation for User Story 2

- [x] T092 [P] [US2] Implement Handlers.Join (validate channel name, call Channels.Server.join, return {:ok, :join, channel_name}, handle password for +k channels) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/join.ex`
- [x] T093 [P] [US2] Implement Handlers.Part (validate, call Channels.Server.part, return {:ok, :part, channel, message}) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/part.ex`
- [x] T094 [P] [US2] Implement Handlers.List (return {:ok, :ui_action, :open_channel_list, %{}}) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/list.ex`
- [x] T095 [US2] Extend ChatLive to handle :join and :part results (subscribe/unsubscribe PubSub, update treebar assigns, switch active channel, load initial messages, enforce 10-channel limit per FR-013) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T096 [US2] Implement ChannelListLive (retro dialog listing all active channels with name, topic, user count; search/filter input) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/channel_list_live.ex`
- [x] T097 [US2] Extend Channels.Server to handle channel destruction when last user leaves an unregistered channel in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`

- [x] T098 [US2] Run tests and verify all US1 + US2 tests pass

**Checkpoint**: US2 complete — multi-channel support working, treebar updates, operator badges, channel lifecycle correct.

---

## Phase 5: User Story 3 — Private Messages (Priority: P3)

**Goal**: /query and /msg enable PM conversations, treebar shows PMs under "Private" with unread indicators, messages persisted bidirectionally

**Independent Test**: Two users open PMs, exchange messages bidirectionally, verify persistence and treebar indicators.

**FRs covered**: FR-028 through FR-032

### Tests for User Story 3

- [x] T099 [P] [US3] Write tests for Handlers.Msg (send PM, open window, error on nonexistent user) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/msg_test.exs`
- [x] T100 [P] [US3] Write tests for Handlers.Query (open PM window, error on nonexistent user) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/query_test.exs`
- [x] T101 [P] [US3] Write tests for Chat.Queries PM functions (insert_private_message, list_private_messages with cursor pagination, conversation lookup via sorted nicknames) in `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_pm_test.exs`

### Implementation for User Story 3

- [x] T102 [P] [US3] Implement Handlers.Msg (validate target exists via Presence, return {:ok, :message, %{target: nick, content: text}}) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/msg.ex`
- [x] T103 [P] [US3] Implement Handlers.Query (validate target exists, return {:ok, :ui_action, :open_query, %{nickname: nick}}) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/query.ex`
- [x] T104 [US3] Extend Chat.Queries with PM functions (insert_private_message, list_private_messages using least/greatest composite index) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex`
- [x] T105 [US3] Extend Chat.Service with send_private_message (policy check → persist → PubSub broadcast to "pm:#{sorted_nicks}") in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [x] T106 [US3] Extend ChatLive to handle PM results: open PM in treebar "Private" section, subscribe to PM PubSub topic, switch view, render PM conversation without nicklist panel, handle unread PM indicators, notification sound hook in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T107 [US3] Run tests and verify all US1–US3 pass

**Checkpoint**: US3 complete — bidirectional PMs working with persistence, treebar indicators, sorted-nickname PubSub topics.

---

## Phase 6: User Story 4 — Slash Commands System (Priority: P4)

**Goal**: Command palette popup on "/", real-time filtering, ↑/↓ history, Tab nickname completion, all remaining commands implemented

**Independent Test**: Type "/" and verify popup, filter, selection. Test ↑/↓ history. Test Tab completion. Execute /nick, /whois, /clear, /away, /quit, /help.

**FRs covered**: FR-033 through FR-037

### Tests for User Story 4

- [x] T108 [P] [US4] Write tests for Handlers.Me (action in channel, action in PM) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/me_test.exs`
- [x] T109 [P] [US4] Write tests for Handlers.Nick (change nickname, taken nickname, invalid nickname, broadcast to shared channels) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/nick_test.exs`
- [x] T110 [P] [US4] Write tests for Handlers.Topic (set topic, +t enforcement, no-permission error) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/topic_test.exs`
- [x] T111 [P] [US4] Write tests for Handlers.Whois (returns user info, not-found error) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/whois_test.exs`
- [x] T112 [P] [US4] Write tests for Handlers.Clear (returns :ui_action :clear_chat) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/clear_test.exs`
- [x] T113 [P] [US4] Write tests for Handlers.Away (set away with message, clear away) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/away_test.exs`
- [x] T114 [P] [US4] Write tests for Handlers.Quit (returns :quit with optional message) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/quit_test.exs`
- [x] T115 [P] [US4] Write tests for Handlers.Help (all commands list, specific command help) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/help_test.exs`

### Implementation for User Story 4

#### Command Handlers

- [x] T116 [P] [US4] Implement Handlers.Me in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/me.ex`
- [x] T117 [P] [US4] Implement Handlers.Nick (validate new nick, check availability via Presence, return {:ok, :nick_change, new_nick}) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/nick.ex`
- [x] T118 [P] [US4] Implement Handlers.Topic in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/topic.ex`
- [x] T119 [P] [US4] Implement Handlers.Whois in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/whois.ex`
- [x] T120 [P] [US4] Implement Handlers.Clear in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/clear.ex`
- [x] T121 [P] [US4] Implement Handlers.Away in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/away.ex`
- [x] T122 [P] [US4] Implement Handlers.Quit in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/quit.ex`
- [x] T123 [P] [US4] Implement Handlers.Help in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/help.ex`

#### Command Palette UI

- [x] T124 [P] [US4] Implement CommandPalette component (retro design system listbox popup above input, shows all commands with descriptions, real-time filtering as user types) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/command_palette.ex`
- [x] T125 [P] [US4] Implement command_palette_hook.js (open on "/" keystroke, filter list, Enter/click to select, Esc to close, push selected command to LiveView) in `apps/retro_hex_chat_web/assets/js/hooks/command_palette_hook.js`
- [x] T126 [P] [US4] Implement keyboard_hook.js (↑/↓ command history navigation from assigns.command_history, Tab nickname completion cycling through nicklist matches) in `apps/retro_hex_chat_web/assets/js/hooks/keyboard_hook.js`

#### LiveView Integration

- [x] T127 [US4] Extend ChatLive to handle :nick_change (update assigns.nickname, update Presence metadata, resubscribe PM topics with new nick, broadcast nick_changed to shared channels), :quit (full disconnect cleanup per services.md, redirect to ConnectLive), :ui_action variants (:clear_chat resets stream, :open_whois shows dialog, :show_help displays text), and command_history tracking (last 50) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T128 [P] [US4] Implement Dialog component (reusable retro dialog: title, body, OK/Cancel buttons) for Whois display in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/dialog.ex`

- [x] T129 [US4] Run tests and verify all US1–US4 pass

**Checkpoint**: US4 complete — full command system with palette, history, tab completion, and all basic commands working.

---

## Phase 7: User Story 5 — Channel Modes and Operator Controls (Priority: P5)

**Goal**: Operators can set channel modes (+m, +t, +k, +i, +l, +o, +v), kick, ban users. Mode enforcement in real time.

**Independent Test**: Create channel, apply each mode, verify enforcement. Test kick and ban independently.

**FRs covered**: FR-038 through FR-042

### Tests for User Story 5

- [x] T130 [P] [US5] Write tests for Channels.Modes (parse "+mt", parse "+k secret", combined modes "+m-m" last wins, all flag types) in `apps/retro_hex_chat/test/retro_hex_chat/channels/modes_test.exs`
- [x] T131 [P] [US5] Write tests for Handlers.Mode (apply single mode, combined modes, missing params, permission denied) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/mode_test.exs`
- [x] T132 [P] [US5] Write tests for Handlers.Kick (kick user, permission denied, self-kick denied, user not in channel) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/kick_test.exs`
- [x] T133 [P] [US5] Write tests for Handlers.Ban (ban user, permission denied, persist for registered channels) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/ban_test.exs`

### Implementation for User Story 5

- [x] T134 [US5] Extend Channels.Modes with full mode parsing: +/-o, +/-v (with nickname param), +/-m, +/-i, +/-t, +/-k (with password param), +/-l (with limit param), combined modes "+mt-i", last-flag-wins for conflicts in `apps/retro_hex_chat/lib/retro_hex_chat/channels/modes.ex`
- [x] T135 [P] [US5] Implement Handlers.Mode (validate mode string, check operator, call Channels.Server.set_mode, broadcast system message) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/mode.ex`
- [x] T136 [P] [US5] Implement Handlers.Kick (validate operator, deny self-kick, call Channels.Server.kick, broadcast kick message) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/kick.ex`
- [x] T137 [P] [US5] Implement Handlers.Ban (validate operator, call Channels.Server.ban, persist for registered channels via Services.Queries) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ban.ex`
- [x] T138 [US5] Extend Channels.Server with set_mode, kick, ban GenServer calls; enforce modes on join (+k password, +i invite-only, +l limit, ban check) and on message send (+m moderated); persist modes for registered channels in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [x] T139 [US5] Extend ChatLive to handle mode changes: update UI when +m disables input for non-ops/non-voiced, show mode change system messages, handle kick event (remove channel, show kick notification), handle ban enforcement on join attempts in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T140 [US5] Run tests and verify all US1–US5 pass

**Checkpoint**: US5 complete — full channel moderation with all modes, kick, ban, and real-time enforcement.

---

## Phase 8: User Story 6 — NickServ: Nick Registration and Protection (Priority: P6)

**Goal**: /ns register, identify, ghost, info, drop. 60-second identify timer. NickServ messages in gold under Services.

**Independent Test**: Register a nick, disconnect, reconnect, verify 60s timer, test ghost command.

**FRs covered**: FR-043 through FR-047

### Tests for User Story 6

- [x] T141 [P] [US6] Write tests for Services.NickServ GenServer (register, identify, ghost, info, drop, registered?, start/cancel identify timer, timeout force-rename with Guest_XXXXX collision handling) in `apps/retro_hex_chat/test/retro_hex_chat/services/nick_serv_test.exs`
- [x] T142 [P] [US6] Write tests for Handlers.Ns (dispatch to NickServ subcommands: register, identify, ghost, info, drop, help; error on invalid subcommand) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/ns_test.exs`
- [x] T143 [P] [US6] Write tests for Services.Queries nick functions (insert/find/delete registered_nick, update last_seen_at) in `apps/retro_hex_chat/test/retro_hex_chat/services/queries_nick_test.exs`

### Implementation for User Story 6

- [x] T144 [US6] Implement Services.Queries nick functions (insert_registered_nick, find_by_nickname, delete_registered_nick, update_last_seen) in `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex`
- [x] T145 [US6] Implement Services.NickServ GenServer (register with bcrypt, identify with password verify, ghost via PubSub force_disconnect, info lookup, drop delete, registered? check, 60s identify timer via Process.send_after, cancel_identify_timer, handle_info for timeout with Guest_XXXXX generation and collision retry) in `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_serv.ex`
- [x] T146 [P] [US6] Implement Services.Policy (identify_required? check, is_owner? check) in `apps/retro_hex_chat/lib/retro_hex_chat/services/policy.ex`
- [x] T147 [P] [US6] Implement Services.Events (Telemetry: nick_registered, nick_identified) in `apps/retro_hex_chat/lib/retro_hex_chat/services/events.ex`
- [x] T148 [US6] Implement Handlers.Ns (parse subcommand, delegate to NickServ GenServer, format results as service messages) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ns.ex`
- [x] T149 [US6] Add NickServ GenServer to supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- [x] T150 [US6] Extend ChatLive to handle NickServ events: on connect check if nick is registered → start identify timer, handle force_rename event (update assigns, resubscribe PM topics, broadcast nick_changed), render NickServ messages in gold under Services treebar section in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T151 [US6] Extend disconnect cleanup in ChatLive.terminate/2 to call NickServ.cancel_identify_timer per services.md ordering contract in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T152 [US6] Run tests and verify all US1–US6 pass

**Checkpoint**: US6 complete — nick registration, 60s timer, ghost sessions, NickServ service messages.

---

## Phase 9: User Story 7 — ChanServ: Channel Registration and Access Lists (Priority: P7)

**Goal**: /cs register, drop, access lists (sop/aop/vop add/del/list), auto-privilege on join, hierarchical permissions, registered channels persist when empty

**Independent Test**: Register channel, add users to access list, verify auto-op/voice on join, verify persistence when empty.

**FRs covered**: FR-048 through FR-053

### Tests for User Story 7

- [x] T153 [P] [US7] Write tests for Services.ChanServ GenServer (register, drop, op/deop, voice/devoice, info, manage_access with hierarchy enforcement, check_access) in `apps/retro_hex_chat/test/retro_hex_chat/services/chan_serv_test.exs`
- [x] T154 [P] [US7] Write tests for Handlers.Cs (dispatch to ChanServ subcommands, permission errors, hierarchy enforcement) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/cs_test.exs`
- [x] T155 [P] [US7] Write tests for Services.Queries channel functions (insert/find/delete registered_channel, access list CRUD, ban CRUD) in `apps/retro_hex_chat/test/retro_hex_chat/services/queries_channel_test.exs`
- [x] T156 [P] [US7] Write tests for Channels.Queries (find registered channel, load persisted state) in `apps/retro_hex_chat/test/retro_hex_chat/channels/queries_test.exs`

### Implementation for User Story 7

- [x] T157 [US7] Implement Services.Queries channel functions (insert/find/delete registered_channel, access list add/del/list, ban add/del/list, load_channel_state) in `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex`
- [x] T158 [P] [US7] Implement Channels.Queries (find_registered_channel, load persisted bans/modes/topic for channel startup) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/queries.ex`
- [x] T159 [US7] Implement Services.ChanServ GenServer (register with founder access entry, drop with cascade delete, op/deop/voice/devoice temporary privileges via Channels.Server, info lookup, manage_access with hierarchical permission enforcement per services.md matrix, check_access) in `apps/retro_hex_chat/lib/retro_hex_chat/services/chan_serv.ex`
- [x] T160 [US7] Implement Handlers.Cs (parse subcommand tree: register, drop, op, deop, voice, devoice, info, help, sop/aop/vop + add/del/list; delegate to ChanServ GenServer) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/cs.ex`
- [x] T161 [US7] Add ChanServ GenServer to supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- [x] T162 [US7] Extend Channels.Server: on join, if channel is registered and user is identified, call ChanServ.check_access and auto-apply privilege (operator for founder/sop/aop, voice for vop) per services.md auto-privilege sequence; keep registered channel process alive when empty in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [x] T163 [US7] Extend ChatLive to render ChanServ messages in gold under Services treebar section in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T164 [US7] Run tests and verify all US1–US7 pass

**Checkpoint**: US7 complete — channel registration, access lists, auto-privilege, hierarchical permissions, persistence.

---

## Phase 10: User Story 8 — Infinite Scroll and Chat Persistence (Priority: P8)

**Goal**: 50-message initial load, infinite scroll up with hourglass, scroll position preservation, "New messages" floating button

**Independent Test**: Send 100+ messages, join, verify 50 load. Scroll up, verify older load. New messages while scrolled → button appears.

**FRs covered**: FR-024 through FR-027

### Tests for User Story 8

- [x] T165 [P] [US8] Write tests for Chat.Queries cursor pagination edge cases (empty channel, exactly 50, >50 with multiple pages, timestamp boundary) in `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_pagination_test.exs`
- [x] T166 [P] [US8] Write LiveView test for scroll behavior (initial load at bottom, phx-hook for infinite scroll trigger) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_scroll_test.exs`

### Implementation for User Story 8

- [x] T167 [P] [US8] Implement scroll_hook.js (detect scroll-to-top → push "load_more" event, auto-scroll to bottom when at bottom and new message arrives, "New messages" button when scrolled up, preserve scroll position during prepend) in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T168 [P] [US8] Implement ScrollLoader component (hourglass/retro design system progress indicator shown during page load) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/scroll_loader.ex`
- [x] T169 [US8] Extend ChatLive with handle_event "load_more" (cursor pagination via Chat.Queries, prepend to stream, loading state), "scroll_to_bottom" event, and "new_messages" floating button logic in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T170 [US8] Run tests and verify all US1–US8 pass

**Checkpoint**: US8 complete — infinite scroll, cursor pagination, scroll preservation, new messages indicator.

---

## Phase 11: User Story 9 — Chat Search (Priority: P9)

**Goal**: Ctrl+F opens retro search dialog, text highlighted in yellow, Find Next/Previous, result counter, database search for older messages

**Independent Test**: Send messages with keyword, search, verify highlighting, navigation, counter.

**FRs covered**: FR-054 through FR-057

### Tests for User Story 9

- [x] T171 [P] [US9] Write tests for Chat.Search (trigram search, case sensitivity, result count, search across loaded and DB messages) in `apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs`
- [x] T172 [P] [US9] Write LiveView test for search dialog (open on Ctrl+F, highlight matches, navigate) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_search_test.exs`

### Implementation for User Story 9

- [x] T173 [US9] Implement Chat.Search (trigram ILIKE query on messages/private_messages content column using GIN index, case sensitivity toggle, result pagination) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/search.ex`
- [x] T174 [P] [US9] Implement SearchBar component (retro dialog: text input, Find Next/Previous buttons, Case Sensitive checkbox, "X of Y" counter) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/search_bar.ex`
- [x] T175 [US9] Extend ChatLive with search state: handle Ctrl+F (open dialog), search query (call Chat.Search, highlight matches in stream, navigate between matches, load DB results for older matches), Esc to close and clear highlights in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T176 [US9] Run tests and verify all US1–US9 pass

**Checkpoint**: US9 complete — full-text search with highlighting, navigation, and database query support.

---

## Phase 12: User Story 10 — Nicklist and User Context Menu (Priority: P10)

**Goal**: Nicklist grouped by role, context menu with role-appropriate options, real-time presence updates

**Independent Test**: Join channel with multiple roles, verify sorting. Right-click context menu. Away status icon change.

**FRs covered**: FR-058 through FR-060

### Tests for User Story 10

- [x] T177 [P] [US10] Write component test for Nicklist (grouping, sorting, role prefixes, user count) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/nicklist_test.exs`
- [x] T178 [P] [US10] Write component test for ContextMenu (role-appropriate options: op sees kick/ban/mode, regular sees only query/whois) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/context_menu_test.exs`

### Implementation for User Story 10

- [x] T179 [P] [US10] Implement ContextMenu component (retro-style popup on right-click: Query, Whois, separator, Kick, Ban, Give/Take Op, Give/Take Voice — conditionally shown based on viewer's operator status) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`
- [x] T180 [US10] Extend Nicklist component with real-time Presence diff handling: joins add to correct group, parts remove, nick changes update position, away status dims icon in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex`
- [x] T181 [US10] Extend ChatLive to handle context menu events: right-click nickname → show context menu, menu item clicks dispatch corresponding commands (/query, /whois, /kick, /ban, /mode +o/-o, /mode +v/-v) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T182 [US10] Run tests and verify all US1–US10 pass

**Checkpoint**: US10 complete — interactive nicklist with context menu, role grouping, real-time presence.

---

## Phase 13: User Story 11 — retro Design System and Dark Theme (Priority: P11)

**Goal**: Full dark theme polish, all components consistent with retro design system, monospace chat fonts, color palette, 3D borders, hourglass cursors

**Independent Test**: Visual inspection of every component against retro reference. Dark theme consistent throughout.

**FRs covered**: FR-061 through FR-064

### Tests for User Story 11

- [x] T183 [P] [US11] Write component tests verifying correct CSS classes and semantic HTML for Window, TitleBar, StatusBar, MenuBar, Toolbar, Dialog components in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/design_system_test.exs`

### Implementation for User Story 11

- [x] T184 [P] [US11] Refine dark-theme.css with complete custom property set: all retro design system overrides for dark backgrounds, borders, text colors, scrollbar styling, button states, input styling in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T185 [P] [US11] Add 16x16 pixel art icons for treebar items (channel, PM, services, user roles) in `apps/retro_hex_chat_web/assets/static/icons/`
- [x] T186 [US11] Polish all components for design consistency: verify 3D beveled borders on all panels, sunken panels for text areas, raised panels for toolbars, proper font stacks (monospace for chat, retro design system pixel font for UI), color palette validation (system #666680, service #d4a017, error #cc4444, action #9b59b6), nickname 12-color palette for dark backgrounds in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/`

- [x] T187 [US11] Visual verification: all US1–US11 pass with consistent dark theme

**Checkpoint**: US11 complete — pixel-perfect retro dark theme across all components.

---

## Phase 14: User Story 12 — UX Polish: Sounds, Dialogs, Menu Bar (Priority: P12)

**Goal**: Functional menu bar with keyboard shortcuts, confirmation dialogs, notification sounds, toolbar actions, proper focus management

**Independent Test**: Navigate all menus, verify keyboard shortcuts. Trigger confirmation dialogs. Enable sounds and verify playback.

**FRs covered**: FR-065 through FR-068

### Tests for User Story 12

- [x] T188 [P] [US12] Write LiveView test for menu bar functionality (File > Disconnect, Edit > Find opens search, View > Toggle Treebar/Nicklist) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_menu_test.exs`
- [x] T189 [P] [US12] Write component test for confirmation Dialog (renders OK/Cancel, blocks action until confirmed) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/dialog_confirm_test.exs`

### Implementation for User Story 12

- [x] T190 [P] [US12] Add notification sound .wav files (message, PM, join) to `apps/retro_hex_chat_web/assets/static/sounds/`
- [x] T191 [P] [US12] Implement sound_hook.js (play .wav on PubSub events: new PM, new message, user join; respect mute setting) in `apps/retro_hex_chat_web/assets/js/hooks/sound_hook.js`
- [x] T192 [US12] Extend MenuBar with functional handlers: File (Disconnect → /quit, Exit), Edit (Find → Ctrl+F search, Clear Window → /clear), View (Toggle Treebar, Toggle Nicklist), Help (About dialog, IRC Commands Reference → /help); keyboard shortcuts (Alt+F, Alt+E, Alt+V, Alt+H) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex`
- [x] T193 [US12] Extend Dialog component with confirmation mode (OK/Cancel with optional reason field, blocks action until confirmed) for kick, ban, drop operations in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/dialog.ex`
- [x] T194 [US12] Extend Toolbar with functional click handlers: Connect/Disconnect toggle, Channel List opens /list, Settings placeholder in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toolbar.ex`
- [x] T195 [US12] Extend ChatLive with hourglass cursor during loading states (CSS cursor: wait), proper focus management (focus returns to input after dialog close, after command palette close) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

- [x] T196 [US12] Run tests and verify all US1–US12 pass

**Checkpoint**: US12 complete — full UX polish with sounds, menus, confirmation dialogs, keyboard shortcuts.

---

## Phase 15: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, Telemetry wiring, static analysis, performance verification

- [x] T197 [P] Wire Telemetry event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/telemetry.ex` for logging domain events (message_sent, user_connected, channel_created, command_executed, rate_limited)
- [x] T198 [P] Add integration test for full disconnect cleanup sequence (cancel NickServ timer → part all channels → untrack Presence → release nickname) per services.md ordering in `apps/retro_hex_chat/test/retro_hex_chat/services/disconnect_cleanup_test.exs`
- [x] T199 [P] Add integration test for NickServ 60-second timer race condition (identify at ~59.9s, verify GenServer serialization handles it correctly) in `apps/retro_hex_chat/test/retro_hex_chat/services/nick_serv_race_test.exs`
- [x] T200 [P] Add integration test for ChanServ auto-privilege on join (identified user with access list entry gets auto-op/voice) in `apps/retro_hex_chat/test/retro_hex_chat/services/chan_serv_auto_privilege_test.exs`
- [x] T201 [P] Add property-based tests (StreamData) for Commands.Parser edge cases (empty input, unicode, very long input, nested slashes) in `apps/retro_hex_chat/test/retro_hex_chat/commands/parser_property_test.exs`
- [x] T202 Run `mix format --check-formatted && mix credo --strict && mix dialyzer` — all must pass with zero violations (SC-006)
- [x] T203 Run full test suite `mix test` — must complete in under 60 seconds (SC-005)
- [x] T204 Run unit-only tests `mix test --only unit` — must complete in under 10 seconds (SC-005)
- [x] T205 Validate quickstart.md by following setup instructions on a clean checkout
- [x] T206 Run `mix test --cover` and establish baseline test coverage percentage; verify coverage does not regress (SC-005, Constitution IV)
- [x] T207 [P] Add load test simulating 50 concurrent users across 10 channels, verifying <200ms message delivery and zero dropped messages (SC-010) in `apps/retro_hex_chat/test/retro_hex_chat/load_test.exs`
- [x] T208 [P] Add performance test seeding 100k messages in a channel and benchmarking cursor pagination query time <100ms (SC-004) in `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_performance_test.exs`
- [x] T209 [P] Add integration test for channel GenServer crash recovery: kill a channel process, verify DynamicSupervisor restarts it, and state is recovered from PostgreSQL for registered channels in `apps/retro_hex_chat/test/retro_hex_chat/channels/crash_recovery_test.exs`
- [x] T210 [P] Add integration test for simultaneous joins: 100 users join a single channel within 1 second, verify nicklist and system messages remain ordered and complete in `apps/retro_hex_chat/test/retro_hex_chat/channels/simultaneous_joins_test.exs`
- [x] T211 [P] Add integration test for PubSub message ordering: verify messages maintain causal ordering within a single channel when sent through the Channel GenServer in `apps/retro_hex_chat/test/retro_hex_chat/channels/message_ordering_test.exs`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phases 3–14)**: All depend on Foundational phase completion
  - US1 (P1): No dependencies on other stories — **MVP**
  - US2 (P2): Builds on US1 (channels extend the #lobby-only chat)
  - US3 (P3): Builds on US1 (PMs use same chat infrastructure)
  - US4 (P4): Builds on US1–US2 (command palette + remaining handlers; weak coupling to US3 for /me in PMs)
  - US5 (P5): Builds on US2 (modes apply to channels)
  - US6 (P6): Builds on US1 (NickServ is independent of channels)
  - US7 (P7): Builds on US5 + US6 (ChanServ requires modes + identified users)
  - US8 (P8): Builds on US1 (infinite scroll extends basic message display)
  - US9 (P9): Builds on US8 (search queries DB, needs pagination)
  - US10 (P10): Builds on US2 + US5 (context menu uses mode commands)
  - US11 (P11): Can start after US1 (CSS polish, independent of logic)
  - US12 (P12): Builds on US4 + US9 (menus trigger commands + search)
- **Polish (Phase 15)**: Depends on all user stories being complete

### Recommended Execution Order (Solo Developer)

```text
Phase 1 → Phase 2 → US1 → US2 → US3 → US4 → US5 → US6 → US7 → US8 → US9 → US10 → US11 → US12 → Phase 15
```

### Parallel Opportunities (Team)

```text
After Phase 2 completes:
  Developer A: US1 → US2 → US5 → US7
  Developer B: US1 → US3 → US6 (independent of channels)
  Developer C: US1 → US4 → US8 → US9
  Developer D: US11 (CSS only, no logic deps) → US12
```

### Within Each User Story

1. Tests MUST be written and FAIL before implementation
2. Domain layer before web layer
3. Schemas → Queries → Services → Handlers → LiveView integration
4. Story complete before moving to next priority

---

## Parallel Example: Phase 2 Foundational

```bash
# All migrations can run in sequence (one batch):
T010 → T011, T012, T013, T014, T015, T016 [P] → T017

# All schema tests in parallel:
T018, T019, T020, T021, T022, T023 [all P]

# All schema implementations in parallel:
T024, T025, T026, T027, T028, T029 [all P]

# Core context skeletons in parallel:
T035+T036 [P] (Accounts tests) → T037+T038+T039+T040 [P] (Accounts impl)
T041 [P] (RateLimit test) → T042+T043 [P] (RateLimit impl)
T045 [P] (Presence test) → T046 [P] (Presence impl)
T047 [P] (Parser test) → T048 [P] (Parser impl)
T051 [P] (Dispatcher test) → T052 (Dispatcher impl)
```

## Parallel Example: User Story 1

```bash
# All US1 tests in parallel (write first, all should fail):
T056, T057, T058, T059, T060, T061, T062 [all P]

# Domain implementation — independent modules in parallel:
T063, T064, T065, T066 [all P]
# Then dependent: T067 (Server depends on Membership, Modes, Policy)
T068, T069 [P] → T070 (Service depends on Policy + Queries)

# Web components all in parallel:
T072, T073, T074, T075, T076, T077, T078, T079 [all P]

# CSS in parallel with components:
T080, T081 [all P]

# LiveViews sequential (depend on components):
T082 → T083 → T084 → T085
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Two users can connect and chat in #lobby with full retro UI
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 → **MVP: real-time chat with retro layout** (deploy!)
3. US2 → Multi-channel support (deploy!)
4. US3 → Private messaging (deploy!)
5. US4 → Full command system with palette (deploy!)
6. US5 → Channel moderation (deploy!)
7. US6 → Nick registration/protection (deploy!)
8. US7 → Channel registration/access lists (deploy!)
9. US8 → Infinite scroll polish (deploy!)
10. US9 → Chat search (deploy!)
11. US10 → Nicklist context menu (deploy!)
12. US11 → Design system polish (deploy!)
13. US12 → UX polish: sounds, menus, dialogs (deploy!)
14. Phase 15 → Final validation and static analysis

Each increment delivers independently testable value without breaking previous stories.

---

## Notes

- [P] tasks = different files, no dependencies — can run in parallel
- [Story] label maps task to specific user story for traceability
- TDD is non-negotiable (Constitution IV): write test → verify fail → implement → verify pass
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All file paths are relative to the umbrella root `/Users/rodrigo/src/retro_hex_chat/`
- Total tasks: 211
