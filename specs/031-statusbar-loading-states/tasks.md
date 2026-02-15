# Tasks: Status Bar & Loading States

**Input**: Design documents from `/specs/031-statusbar-loading-states/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: TDD is NON-NEGOTIABLE per constitution. Tests are written first for all user stories.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: CSS files and shared components needed by multiple user stories

- [x] T001 [P] Create connection banner CSS in `apps/retro_hex_chat_web/assets/css/connection-banner.css` — red/green banner styles, fade-out animation, non-blocking positioning at top of chat area, z-index below reconnect overlay
- [x] T002 [P] Create loading spinner CSS in `apps/retro_hex_chat_web/assets/css/loading-spinner.css` — centered spinner with 98.css progress bar animation, descriptive text, retry button styles
- [x] T003 [P] Create connection progress CSS in `apps/retro_hex_chat_web/assets/css/connection-progress.css` — step indicator styles with checkmark/hourglass states, centered layout
- [x] T004 Import new CSS files in `apps/retro_hex_chat_web/assets/css/app.css` — add connection-banner.css, loading-spinner.css, connection-progress.css in the correct layers (Components layer)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared server-side helpers and status bar restructuring that ALL user stories depend on

- [x] T005 Create connection helper module at `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/connection.ex` — define `handle_event("ping", ...)` that echoes client_time via push_event("pong"), `handle_event("lag_update", ...)` that computes lag_status from thresholds (normal <200ms, warning 200-499ms, critical 500ms+, timeout nil), and helper `lag_status/1` function. Add @spec for all public functions
- [x] T006 Add new assigns to ChatLive mount in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `connection_state: :connected`, `lag_ms: nil`, `lag_status: :normal`, `loading_channel: nil`, `connection_established: true` assigns. Wire connection helper handle_events into the LiveView
- [x] T007 Restructure status bar component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_bar.ex` — change from 5 flat fields to 3-section layout (left: channel + user count, center: connection state with colored indicator, right: lag + clock + mute). Add new attrs: `connection_state`, `lag_ms`, `lag_status`. Use fixed min-widths for lag/clock fields to prevent layout shifts. Add @spec
- [x] T008 Update status bar CSS in `apps/retro_hex_chat_web/assets/css/shell.css` — add 3-section flexbox layout for status bar, fixed min-widths for lag/clock fields, lag color classes (normal/warning/critical), connection state icon colors
- [x] T009 Update chat_live.html.heex template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — pass new assigns (connection_state, lag_ms, lag_status) to status_bar component, add hook attachment points for LagHook and ClockHook on status bar fields

**Checkpoint**: Foundation ready — status bar shows 3-section layout with placeholders, ping/pong handler ready on server

---

## Phase 3: User Story 1 — Enhanced Status Bar with Lag & Clock (Priority: P1) MVP

**Goal**: Connected users see a rich status bar with real-time lag measurement (color-coded), connection state indicator, and local clock

**Independent Test**: Connect a user, verify 3-section status bar renders with lag value updating every 30s, clock showing current HH:MM, and connection state showing "Connected" in green

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T010 [P] [US1] Write JS lib tests for lag logic in `apps/retro_hex_chat_web/assets/test/lib/lag.test.js` — test calculateLag(clientTime, now) returns correct ms, test classifyLag(ms) returns normal/warning/critical/timeout for threshold boundaries (0, 199, 200, 499, 500, null), test isTimeout(elapsed, threshold) logic
- [x] T011 [P] [US1] Write JS lib tests for clock logic in `apps/retro_hex_chat_web/assets/test/lib/clock.test.js` — test formatTime(date) returns HH:MM in 24h format, test with various hours/minutes including midnight (00:00) and noon (12:00), test locale handling
- [x] T012 [P] [US1] Write JS hook tests for LagHook in `apps/retro_hex_chat_web/assets/test/hooks/lag_hook.test.js` — test mounted() starts ping interval, test destroyed() clears timers, test disconnected() stops pinging, test reconnected() restarts pinging, test pong event handler calculates lag and pushes lag_update
- [x] T013 [P] [US1] Write JS hook tests for ClockHook in `apps/retro_hex_chat_web/assets/test/hooks/clock_hook.test.js` — test mounted() renders current time and starts interval, test destroyed() clears interval, test interval updates DOM text content
- [x] T014 [P] [US1] Write Elixir component tests for updated status bar in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/status_bar_test.exs` — test 3-section rendering with all connection states (connecting/connected/disconnected/reconnecting), test lag display with normal/warning/critical/timeout values, test lag color classes, test clock placeholder rendering, test layout stability (fixed widths)
- [x] T015 [P] [US1] Write Elixir tests for connection helper in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/helpers/connection_test.exs` — test ping event echoes pong with client_time, test lag_update event updates assigns (lag_ms + lag_status), test lag_status/1 threshold classification

### Implementation for User Story 1

- [x] T016 [P] [US1] Implement lag lib module in `apps/retro_hex_chat_web/assets/js/lib/lag.js` — export calculateLag(clientTime, now), classifyLag(ms) returning {value, status} where status is 'normal'/'warning'/'critical'/'timeout', export PING_INTERVAL=30000, PING_TIMEOUT=10000 constants
- [x] T017 [P] [US1] Implement clock lib module in `apps/retro_hex_chat_web/assets/js/lib/clock.js` — export formatTime(date) returning HH:MM string using toLocaleTimeString with hour12:false, export CLOCK_INTERVAL=30000 constant
- [x] T018 [US1] Implement LagHook in `apps/retro_hex_chat_web/assets/js/hooks/lag_hook.js` — mounted(): start 30s ping interval calling pushEvent("ping", {client_time}), set 10s timeout for each ping. handleEvent("pong"): calculate lag via lag.js lib, pushEvent("lag_update", {lag_ms}), clear timeout. disconnected(): clear interval+timeout. reconnected(): restart interval. destroyed(): clear all timers. Follow hook=wiring, lib=logic pattern
- [x] T019 [US1] Implement ClockHook in `apps/retro_hex_chat_web/assets/js/hooks/clock_hook.js` — mounted(): render formatTime(new Date()) to el.innerText, start 30s interval. destroyed(): clear interval. Follow hook=wiring, lib=logic pattern
- [x] T020 [US1] Register LagHook and ClockHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add to Hooks object
- [x] T021 [US1] Wire hooks in template `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — attach phx-hook="LagHook" to lag display field, phx-hook="ClockHook" to clock field, ensure both have unique IDs

**Checkpoint**: Status bar shows live lag (color-coded), connection state, and ticking clock. Ping/pong flows through LiveView channel.

---

## Phase 4: User Story 2 — Connection Banners for Brief Disconnections (Priority: P2)

**Goal**: Brief disconnections (1-10s) show a non-blocking red banner at top of chat area with countdown; reconnection shows green banner that fades after 3s

**Independent Test**: Simulate network interruption after connecting. Verify: no banner for <1s drops, red banner with countdown for >1s drops, green banner on reconnect that fades in 3s, banner hidden when full overlay appears

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T022 [P] [US2] Write JS lib tests for connection banner state machine in `apps/retro_hex_chat_web/assets/test/lib/connection_banner.test.js` — test initial state is 'hidden', test disconnect after wasConnected=true starts debounce, test disconnect before wasConnected=true does nothing (initial load suppression), test debounce completes → state becomes 'disconnected', test reconnect during debounce → stays 'hidden', test reconnect after 'disconnected' → state becomes 'reconnected', test 'reconnected' auto-transitions to 'hidden' after 3s, test overlay visible → forces 'hidden'
- [x] T023 [P] [US2] Write JS hook tests for ConnectionBannerHook in `apps/retro_hex_chat_web/assets/test/hooks/connection_banner_hook.test.js` — test mounted() initializes state, test disconnected() triggers debounce, test reconnected() cancels debounce and shows green, test destroyed() clears all timers, test overlay coexistence (banner hides when overlay visible)
- [x] T024 [P] [US2] Write Elixir component tests for connection banner in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/connection_banner_test.exs` — test renders empty container with hook attachment, test data attributes for configuration (debounce time, fade duration)

### Implementation for User Story 2

- [x] T025 [P] [US2] Implement connection banner lib in `apps/retro_hex_chat_web/assets/js/lib/connection_banner.js` — export createBannerStateMachine() with states (hidden/disconnected/reconnected), transition functions (onDisconnect/onReconnect/onOverlayVisible), debounce logic (1s), countdown management, fade timer (3s). Export DEBOUNCE_MS=1000, FADE_MS=3000 constants
- [x] T026 [US2] Implement ConnectionBannerHook in `apps/retro_hex_chat_web/assets/js/hooks/connection_banner_hook.js` — mounted(): create state machine, set wasConnected=false. disconnected(): if wasConnected, call onDisconnect → renders red banner DOM with countdown after debounce. reconnected(): set wasConnected=true, call onReconnect → renders green banner if was showing red, auto-fades. Check for reconnect overlay visibility via DOM query. destroyed(): clear all timers. Update banner DOM content (message + countdown)
- [x] T027 [US2] Create connection banner Elixir component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/connection_banner.ex` — function component rendering a div with phx-hook="ConnectionBannerHook", data attributes for debounce/fade config, positioned at top of chat area. Add @spec
- [x] T028 [US2] Register ConnectionBannerHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add to Hooks object
- [x] T029 [US2] Add connection banner to chat template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — render connection_banner component at top of chat area (above message stream, below toolbar)

**Checkpoint**: Brief disconnections show red banner with countdown, reconnections show green banner that fades. No banner for <1s drops or during initial load. Banner hides when full overlay appears.

---

## Phase 5: User Story 3 — Connection Progress Indicator (Priority: P3)

**Goal**: During initial connection (on ConnectLive → ChatLive navigation), users see step-by-step progress instead of a blank screen

**Independent Test**: Open application fresh, observe progress steps transitioning from in-progress to completed as connection establishes. Verify retry button appears after 30s timeout.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T030 [P] [US3] Write Elixir component tests for connection progress in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/connection_progress_test.exs` — test renders steps with correct initial states (first step in-progress, rest pending), test completed step shows checkmark, test in-progress step shows hourglass/spinner, test retry button rendering

### Implementation for User Story 3

- [x] T031 [US3] Create connection progress Elixir component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/connection_progress.ex` — function component rendering step-by-step progress indicator. Steps: "Resolving server..." → "Connecting..." → "Waiting for response...". Each step has status attr (pending/in_progress/completed). Renders checkmark for completed, hourglass for in_progress. Shows retry button on timeout. Add @spec
- [x] T032 [US3] Add connection progress to ChatLive mount flow — show connection_progress component during initial load in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`, hide when fully connected. Add `connection_progress_step` assign to ChatLive, transition steps during mount sequence in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T033 [US3] Implement timeout and retry logic — add 30s timeout via Process.send_after in ChatLive mount, handle_info callback to set timeout state showing retry button. Retry button triggers re-mount via push_navigate

**Checkpoint**: Fresh page load shows step-by-step progress indicator. Steps transition to completed as connection establishes. Retry available on 30s timeout.

---

## Phase 6: User Story 4 — Channel History Loading Spinner (Priority: P4)

**Goal**: Switching channels shows a centered spinner while message history loads, preventing blank chat areas

**Independent Test**: Switch to a channel, verify spinner appears centered in chat area with "Loading messages..." text, verify spinner disappears when messages render. Rapid switching shows spinner for latest channel only.

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T034 [P] [US4] Write Elixir component tests for loading spinner in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/loading_spinner_test.exs` — test renders spinner with text when loading=true, test renders nothing when loading=false, test renders retry button when timeout=true, test spinner does not block pointer events (CSS class)
- [x] T035 [P] [US4] Write Elixir tests for loading_channel assign flow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test joining channel sets loading_channel assign, test loading_channel clears after messages stream, test rapid channel switch overwrites loading_channel to latest channel

### Implementation for User Story 4

- [x] T036 [US4] Create loading spinner Elixir component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/loading_spinner.ex` — function component with attrs: loading (boolean), text (string, default "Loading messages..."), timeout (boolean, default false). Renders centered 98.css progress bar with text. Shows retry button when timeout. pointer-events: none on container to not block UI. Add @spec
- [x] T037 [US4] Add loading_channel assign management to channel helper in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex` — set `loading_channel: channel_name` at start of join_channel, set `loading_channel: nil` after messages are streamed. Each new join_channel call naturally overwrites the previous loading_channel value
- [x] T038 [US4] Add loading spinner to chat template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — render loading_spinner component conditionally when @loading_channel is not nil, position centered within the chat message area. Add 30s timeout via Process.send_after for loading timeout

**Checkpoint**: Channel switching shows spinner, spinner disappears when messages load. Rapid switching shows spinner for latest channel. Non-blocking UI.

---

## Phase 7: User Story 5 — Channel List Loading Progress Bar (Priority: P5)

**Goal**: Channel list page shows a progress bar with count while channels are being fetched

**Independent Test**: Navigate to channel list, verify progress bar appears with count, verify it disappears and full list renders when loading completes. Verify retry on 30s timeout.

### Tests for User Story 5

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T039 [P] [US5] Write Elixir LiveView tests for channel list loading in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_live_test.exs` — test initial render shows loading state with progress bar, test after channels loaded shows channel list and hides progress bar, test channel count updates during loading, test 30s timeout shows retry option

### Implementation for User Story 5

- [x] T040 [US5] Refactor ChannelListLive to async loading in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/channel_list_live.ex` — change mount/3 to assign loading: true, channel_count: 0, channels: []. Use send(self(), :load_channels) pattern to defer channel loading. Implement handle_info(:load_channels) to call Autocomplete.list_visible_channels and update assigns (loading: false, channels: result, channel_count: length(result)). Add 30s timeout with retry
- [x] T041 [US5] Update ChannelListLive template to show progress bar — add 98.css progress bar element when @loading is true, show "Fetching channels... {@channel_count} found" text, show retry button on timeout. Hide progress bar and show channel table when @loading is false

**Checkpoint**: Channel list page shows progress bar during load, full list when complete. Retry on 30s timeout.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, integration testing, and final validation

- [x] T042 [P] Add help topics for status bar features in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — add topics: "Status Bar" (Features category, explains 3-section layout), "Lag Indicator" (Features category, explains color thresholds and measurement), "Connection States" (Features category, explains 4 states and visual indicators). Update "See Also" cross-references in related existing topics
- [x] T043 [P] Write help topics tests in `apps/retro_hex_chat/test/retro_hex_chat/chat/help_topics_test.exs` — test new topics exist, test topic content includes key terms, test See Also cross-references
- [x] T044 [P] Write E2E integration test for status bar flow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test full status bar renders with all sections on chat page load, test ping/pong event flow updates lag display, test connection state indicator shows "Connected"
- [x] T045 Run full CI-equivalent validation pipeline per CLAUDE.md — compile with warnings-as-errors, then in parallel: format check, credo strict, ESLint+Prettier (make lint.js), inline style audit (make lint.css), JS tests (npm test), Elixir tests with E2E (mix test --include e2e), dialyzer

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 CSS files — BLOCKS all user stories
- **User Stories (Phases 3-7)**: All depend on Phase 2 completion
  - US1 (Phase 3): No cross-story dependencies
  - US2 (Phase 4): No cross-story dependencies (uses own hook, independent of lag/clock)
  - US3 (Phase 5): No cross-story dependencies (different LiveView area)
  - US4 (Phase 6): No cross-story dependencies (channel helper modification)
  - US5 (Phase 7): No cross-story dependencies (separate LiveView)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Phase 2 (status bar restructure + connection helper) — No other story deps
- **User Story 2 (P2)**: Depends on Phase 2 — No other story deps (banner is independent of lag/clock)
- **User Story 3 (P3)**: Depends on Phase 2 — No other story deps (connection progress is in mount flow)
- **User Story 4 (P4)**: Depends on Phase 2 — No other story deps (channel helper modification)
- **User Story 5 (P5)**: Depends on Phase 2 — No other story deps (separate ChannelListLive)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- JS lib modules before hooks (hook = wiring, lib = logic)
- Elixir components before template integration
- Hook registration before template hook attachment
- Story complete before moving to next priority

### Parallel Opportunities

- Phase 1: All CSS tasks (T001-T003) can run in parallel
- Phase 2: T005-T009 are sequential (each depends on prior)
- Phase 3 (US1): Tests T010-T015 in parallel, then T016-T017 in parallel, then T018-T021 sequential
- Phase 4 (US2): Tests T022-T024 in parallel, then T025 first, then T026-T029 sequential
- Phase 5 (US3): T030 then T031-T033 sequential
- Phase 6 (US4): Tests T034-T035 in parallel, then T036-T038 sequential
- Phase 7 (US5): T039 then T040-T041 sequential
- Phase 8: T042-T044 in parallel, T045 last

---

## Parallel Example: User Story 1

```bash
# Launch all tests for US1 together (6 test files, all different files):
T010: "JS lib tests for lag in assets/test/lib/lag.test.js"
T011: "JS lib tests for clock in assets/test/lib/clock.test.js"
T012: "JS hook tests for LagHook in assets/test/hooks/lag_hook.test.js"
T013: "JS hook tests for ClockHook in assets/test/hooks/clock_hook.test.js"
T014: "Elixir component tests for status bar in test/.../status_bar_test.exs"
T015: "Elixir tests for connection helper in test/.../connection_test.exs"

# Then launch lib modules together (different files):
T016: "Lag lib module in assets/js/lib/lag.js"
T017: "Clock lib module in assets/js/lib/clock.js"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (CSS files)
2. Complete Phase 2: Foundational (status bar restructure, connection helper, assigns)
3. Complete Phase 3: User Story 1 (lag measurement, clock, connection state in status bar)
4. **STOP and VALIDATE**: Test US1 independently — status bar shows lag, clock, connection state
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo (banners for disconnections)
4. Add User Story 3 → Test independently → Deploy/Demo (connection progress)
5. Add User Story 4 → Test independently → Deploy/Demo (channel history spinner)
6. Add User Story 5 → Test independently → Deploy/Demo (channel list progress)
7. Polish phase → Help topics, E2E tests, full CI validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (lag + clock + connection state)
   - Developer B: User Story 2 (connection banners)
   - Developer C: User Stories 3+4+5 (loading states)
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- All JS follows "hook = wiring, lib = logic" pattern (Constitution IV)
- All new Elixir public functions MUST have @spec (Constitution VI)
- No database migrations — all state is ephemeral
- Total tasks: 45 (4 setup + 5 foundational + 12 US1 + 8 US2 + 4 US3 + 5 US4 + 3 US5 + 4 polish)
