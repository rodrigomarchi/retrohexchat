# Tasks: Log Viewer

**Input**: Design documents from `/specs/008-log-viewer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDD is non-negotiable per Constitution Principle IV. Tests are written before or alongside implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Foundational (Domain Structs & Session Extension)

**Purpose**: Pure domain structs shared across all user stories — MUST complete before any user story work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T001 [P] Write tests + implement LogFilter struct (new/0, new/1, validate/1, escape_text/1) with validation rules (no future dates, date_from <= date_to, page >= 1, metacharacter escaping) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/log_filter.ex` and `apps/retro_hex_chat/test/retro_hex_chat/chat/log_filter_test.exs`
- [x] T002 [P] Write tests + implement DisplayPreferences struct (new/0, toggle_event/2, set_timestamp_format/2, format_timestamp/2, visible_type?/2) with defaults (all events visible, :hh_mm_ss) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/display_preferences.ex` and `apps/retro_hex_chat/test/retro_hex_chat/chat/display_preferences_test.exs`
- [x] T003 [P] Write tests + implement LogPage struct (new/3 computes total_pages from total_count and per_page) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/log_page.ex` and `apps/retro_hex_chat/test/retro_hex_chat/chat/log_page_test.exs`
- [x] T004 Extend Session with set_log_preferences/2 and log_preferences/1 (getter returns DisplayPreferences.new() default) + tests in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` and `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`

**Checkpoint**: All shared domain structs ready — user story implementation can begin

---

## Phase 2: User Story 1 — Search and Browse Chat History (Priority: P1) 🎯 MVP

**Goal**: Registered users can open a Log Viewer dialog, filter by channel/PM/date/nickname/text, and browse paginated results. Guest users see session-only data.

**Independent Test**: Open Log Viewer via Alt+L, select a channel, apply date/text filters, verify paginated results with correct formatting, verify guest limitation.

### Domain Layer (US1)

- [x] T005 [P] [US1] Write integration tests for LogQueries — search_channel_log with all filter combinations (source, date range, nickname, text, pagination), search_pm_log bidirectional lookup, count_channel_log, count_pm_log, list_user_channels (DISTINCT sorted), list_user_pm_partners (DISTINCT sorted) in `apps/retro_hex_chat/test/retro_hex_chat/chat/log_queries_test.exs`
- [x] T006 [US1] Implement LogQueries module — composable Ecto queries with optional where clauses for channel_name, date range (inserted_at between), author_nickname ILIKE, content ILIKE with escape_text, offset/limit pagination, chronological order in `apps/retro_hex_chat/lib/retro_hex_chat/chat/log_queries.ex`

### Web Layer (US1)

- [x] T007 [US1] Create LogViewerDialog component — retro dialog (z-index 200) with: channel/PM grouped dropdown, date range inputs (type="date"), nickname + text search fields, Search button, Refresh button, results area with message list (timestamps, nicknames, content), system event styling (.log-system-event), pagination controls (Previous/Next + "Page X of Y"), empty state ("No results found — try broadening your search criteria"), loading indicator in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/log_viewer_dialog.ex`
- [x] T008 [US1] Add log viewer assigns to ChatLive assign_defaults (show_log_viewer, log_filter, log_source_options, log_page, log_loading, log_preferences, log_exporting, log_error) + implement open_log_viewer (populate source_options from LogQueries.list_user_channels/list_user_pm_partners or session data for guests), close_log_viewer (reset assigns), Alt+L toggle in window_keydown, Escape close in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T009 [US1] Implement ChatLive filter/search/pagination handlers — log_set_source (set source + source_type, trigger search), log_set_date_from/log_set_date_to (parse date, validate via LogFilter.validate, trigger search), log_search (set nickname + text, reset to page 1, trigger search), log_page (navigate to page N), log_refresh (re-run current query) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T010 [US1] Add LogViewerDialog to ChatLive template with all attrs bound (visible, filter, page, preferences, source_options, loading, exporting, error) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T011 [US1] Implement guest user session-only log viewing — when not registered, derive source_options from session.channels + session.pm_conversations, filter in-memory chat_messages stream data instead of DB queries, no historical data access in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T012 [US1] Add menu bar item (Tools > Log Viewer) and toolbar button for Log Viewer in ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T013 [US1] Add log viewer CSS styles — dialog layout, filter bar, results area, system event styling, pagination controls, loading state in `apps/retro_hex_chat_web/assets/css/layout.css` and dark theme counterparts in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T014 [US1] Write ChatLive integration tests for US1 — open/close dialog, Alt+L toggle, Escape close, channel dropdown selection, date range filter, text search, nickname filter, pagination (next/prev/page indicator), empty results message, guest user restriction (session-only data), menu bar item, toolbar button in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/log_viewer_test.exs`

**Checkpoint**: User Story 1 complete — Log Viewer opens, searches, filters, and paginates independently

---

## Phase 3: User Story 2 — Export Filtered Logs (Priority: P2)

**Goal**: Users can export filtered log results as .txt (plain text) or .html (styled with formatting preserved) via browser download.

**Independent Test**: Apply a filter, click Export > .txt or .html, verify downloaded file content matches filtered results with correct format.

### Domain Layer (US2)

- [x] T015 [P] [US2] Write tests for LogExporter — export_txt format ([HH:MM:SS] <Nick> content, system events with asterisk), export_html format (standalone HTML with embedded CSS, IRC color classes, Formatter.to_safe_html integration), generate_filename (strips # from channel, date range pattern, extension), display preferences applied (event filtering, timestamp format) in `apps/retro_hex_chat/test/retro_hex_chat/chat/log_exporter_test.exs`
- [x] T016 [US2] Implement LogExporter module — export/3 dispatcher, export_txt/2 (one message per line with formatted timestamps), export_html/2 (standalone HTML document with embedded dark-theme CSS and IRC color classes using Formatter.to_safe_html/2), generate_filename/2 in `apps/retro_hex_chat/lib/retro_hex_chat/chat/log_exporter.ex`

### Web Layer (US2)

- [x] T017 [US2] Create DownloadHook JS — handle "download_file" push_event, decode base64 content, create Blob with mime_type, create anchor element with download attribute, trigger click, cleanup + register hook in `apps/retro_hex_chat_web/assets/js/hooks/download_hook.js` and `apps/retro_hex_chat_web/assets/js/app.js`
- [x] T018 [US2] Implement ChatLive log_export handler — validate results exist, fetch ALL matching messages (not just current page) using LogQueries with per_page override, generate export via LogExporter.export/3, encode to base64, push_event("download_file", ...), manage log_exporting state in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T019 [US2] Add export controls to LogViewerDialog — Export dropdown/buttons (.txt / .html), disabled state when log_page is nil or entries empty, exporting progress indicator in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/log_viewer_dialog.ex`
- [x] T020 [US2] Write ChatLive integration tests for US2 — export .txt button click, export .html button click, export disabled when no results, push_event("download_file") assertion with correct filename/mime_type in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/log_viewer_test.exs`

**Checkpoint**: User Stories 1 AND 2 both work independently — search + export functional

---

## Phase 4: User Story 3 — Configure Display Preferences (Priority: P3)

**Goal**: Users can toggle system event visibility (joins, parts, kicks, mode changes, topic changes) and choose timestamp format. Preferences persist for the session and affect both display and export.

**Independent Test**: Toggle off join events, verify they disappear from results. Change timestamp format, verify timestamps update. Export and verify preferences applied.

- [x] T021 [US3] Add display preference controls to LogViewerDialog — 5 event type checkboxes (Show Joins, Show Parts, Show Kicks, Show Mode Changes, Show Topic Changes), timestamp format radio buttons or dropdown (HH:MM / HH:MM:SS / DD/MM HH:MM) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/log_viewer_dialog.ex`
- [x] T022 [US3] Implement ChatLive preference handlers — log_toggle_event (toggle via DisplayPreferences.toggle_event, persist to session via set_log_preferences, refresh display), log_set_timestamp_format (set via DisplayPreferences.set_timestamp_format, persist, refresh) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T023 [US3] Apply DisplayPreferences filtering to log results rendering — filter system events by visible_type? in LogViewerDialog, format timestamps via DisplayPreferences.format_timestamp in component rendering in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/log_viewer_dialog.ex`
- [x] T024 [US3] Write ChatLive integration tests for US3 — toggle each event type on/off, verify messages filtered in display, change timestamp format and verify, preferences persist across dialog close/reopen, preferences applied to export output in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/log_viewer_test.exs`

**Checkpoint**: All 3 user stories complete and independently testable

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, data-testid attrs, E2E tests, linter/test verification

- [x] T025 [P] Add help topics — feature-log-viewer (overview, filters, pagination, keyboard shortcut), feature-log-export (.txt and .html formats, filename pattern, preferences in export) + update keyboard shortcuts topic (Alt+L) + cross-references with related topics + tests in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` and `apps/retro_hex_chat/test/retro_hex_chat/chat/help_topics_test.exs`
- [x] T026 [P] Add data-testid attributes to all interactive elements in LogViewerDialog (log-viewer-dialog, log-source-select, log-date-from, log-date-to, log-nickname-input, log-text-input, log-search-btn, log-refresh-btn, log-prev-btn, log-next-btn, log-page-indicator, log-export-txt, log-export-html, log-toggle-joins, log-toggle-parts, log-toggle-kicks, log-toggle-modes, log-toggle-topics, log-timestamp-format, log-results-area, log-empty-state, log-loading) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/log_viewer_dialog.ex`
- [x] T027 Write E2E tests — US1: open/close, Alt+L, channel search with results, pagination, empty state, guest mode; US2: export .txt, export .html, disabled when empty; US3: toggle events, change timestamp format in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/log_viewer_e2e_test.exs`
- [x] T028 Linter verification — mix format --check-formatted, mix credo --strict, mix dialyzer: 0 errors
- [x] T029 Full test suite verification — all domain + web + E2E tests pass with 0 failures

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies — can start immediately. BLOCKS all user stories.
- **US1 (Phase 2)**: Depends on Phase 1 completion. BLOCKS US2 (export needs search results).
- **US2 (Phase 3)**: Depends on Phase 2 (needs LogViewerDialog + search results to export).
- **US3 (Phase 4)**: Depends on Phase 2 (needs LogViewerDialog to add preference controls). Can run in parallel with US2.
- **Polish (Phase 5)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Foundational → US1. No other story dependencies. MVP deliverable.
- **US2 (P2)**: Foundational → US1 → US2. Needs search results to export.
- **US3 (P3)**: Foundational → US1 → US3. Needs LogViewerDialog to add controls. Can be parallel with US2.

### Within Each User Story

- Domain tests before domain implementation (TDD)
- Domain modules before web layer
- Component before ChatLive handlers (component defines the UI contract)
- ChatLive handlers before integration tests
- CSS alongside component implementation

### Parallel Opportunities

**Phase 1 (Foundational)**:
```
T001 (LogFilter) ─┐
T002 (DisplayPrefs)├─ All 3 in parallel (different files)
T003 (LogPage) ───┘
T004 (Session) ──── After T002 (depends on DisplayPreferences)
```

**Phase 2 (US1)**:
```
T005 (LogQueries tests) ─┬─ Parallel (domain vs web files)
T007 (Component) ────────┘
T006 (LogQueries impl) ── After T005
T008-T014 ─────────────── Sequential (same files)
```

**Phase 3 + Phase 4 (US2 + US3)**:
```
T015 (Exporter tests) ─┬─ US2 and US3 can run in parallel
T021 (Pref controls) ──┘  after US1 completes
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Foundational structs (T001-T004)
2. Complete Phase 2: US1 Search & Browse (T005-T014)
3. **STOP and VALIDATE**: Log Viewer opens, searches, filters, paginates
4. Proceed to US2 + US3

### Incremental Delivery

1. Phase 1 → Foundation ready
2. Phase 2 → US1 complete → **Log Viewer MVP** (search + browse)
3. Phase 3 → US2 complete → Export capability added
4. Phase 4 → US3 complete → Display preferences added
5. Phase 5 → Polish → Help docs, E2E tests, linter clean

---

## Notes

- No new migrations — all new entities are in-memory only
- Reads from existing `messages` and `private_messages` tables
- Guest users use in-memory stream data, not DB queries
- Export uses push_event + DownloadHook JS (base64 Blob pattern)
- DisplayPreferences stored in Session struct (per-session, not persisted to DB)
- LogQueries uses composable Ecto queries with offset-based pagination
- retro dialog pattern consistent with Channel Central, Address Book, etc.
