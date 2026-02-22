# Tasks: URL Catcher

**Input**: Design documents from `/specs/005-url-catcher/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — Constitution Principle IV (TDD) is non-negotiable.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Add dependencies and verify baseline before feature work

- [x] T001 Add `{:req, "~> 0.5"}` to domain app deps in `apps/retro_hex_chat/mix.exs` and run `mix deps.get`
- [x] T002 Verify baseline: run `make test` (all tests pass) and `make lint` (all linters clean)

---

## Phase 2: Foundational — URL Detection Engine

**Purpose**: Core `URLDetector` module that ALL user stories depend on (US1 for linkification, US2 for capture, US3 for preview triggers)

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 [P] Write unit tests for `URLDetector.extract_urls/1` in `apps/retro_hex_chat/test/retro_hex_chat/chat/url_detector_test.exs` — cover: simple http/https URLs, trailing punctuation trimming (`.` `,` `!` `?` `:` `;`), balanced parentheses (Wikipedia-style), balanced brackets, query params + fragments, multiple URLs, IRC format codes in input, empty input, no URLs, bare domains NOT detected, URL-only messages, `http://` vs `https://`
- [x] T004 [P] Write property-based tests for `URLDetector.extract_urls/1` in `apps/retro_hex_chat/test/retro_hex_chat/chat/url_detector_test.exs` — invariants: every returned URL starts with `http://` or `https://`, every returned URL was present in the input text, no trailing `.` `,` `!` `?` on any returned URL
- [x] T005 Implement `URLDetector.extract_urls/1` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/url_detector.ex` — two-phase: greedy regex `~r{https?://[^\s<>]+}i` then post-process trim for trailing punctuation and balanced parens/brackets. Strip IRC format codes via `Formatter.strip/1` before detection. Add `@spec`, module doc.
- [x] T006 [P] Write unit tests for `URLDetector.linkify/1` in `apps/retro_hex_chat/test/retro_hex_chat/chat/url_detector_test.exs` — cover: single URL produces `<a>` tag with correct attrs (`target="_blank"`, `rel="noopener noreferrer"`, `class="chat-link"`, `title`), non-URL text is HTML-escaped, multiple URLs each get own `<a>`, URLs > 100 chars get truncated display text with `...`, empty string, no URLs, XSS in surrounding text is escaped
- [x] T007 [P] Write unit tests for `URLDetector.linkify_html/1` in `apps/retro_hex_chat/test/retro_hex_chat/chat/url_detector_test.exs` — cover: URL inside `<span class="irc-bold">` gets wrapped in `<a>`, URL spanning text without spans, preserves existing span classes, long URL truncation in HTML context, multiple URLs in formatted HTML
- [x] T008 Implement `URLDetector.linkify/1` and `URLDetector.linkify_html/1` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/url_detector.ex` — `linkify/1` takes plain text, returns HTML string; `linkify_html/1` takes Formatter HTML output, returns HTML with URLs wrapped in `<a>` tags. Both truncate display text for URLs > 100 chars. Add `@spec` for both.
- [x] T009 Run `mix format`, `mix credo --strict`, `mix dialyzer` on domain app — fix any issues

**Checkpoint**: URLDetector ready — all 3 public functions tested and passing. User story implementation can now begin.

---

## Phase 3: User Story 1 — Clickable URLs in Chat Messages (Priority: P1) MVP

**Goal**: URLs in chat messages (channels + PMs) render as clickable links with distinct styling. Clicking opens in new tab. Trailing punctuation excluded. Long URLs visually truncated.

**Independent Test**: Send a message with a URL in a channel → verify it renders as an underlined, colored clickable link that opens in a new tab.

### Tests for User Story 1

- [x] T010 [P] [US1] Write LiveView tests for clickable URL rendering in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_test.exs` — cover: message with URL renders `<a>` tag with `chat-link` class, `target="_blank"`, `rel="noopener noreferrer"`; surrounding text renders normally; URL with trailing period excludes the period from link; URL with query params and fragment is fully clickable; message with multiple URLs has multiple independent `<a>` tags; PM message with URL also renders as link
- [x] T011 [P] [US1] Write LiveView tests for long URL truncation in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_test.exs` — cover: URL > 100 chars has truncated display text with `...` but full URL in `href`; URL exactly 100 chars is NOT truncated
- [x] T012 [P] [US1] Write LiveView tests for URL + IRC formatting interaction in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_test.exs` — cover: bold-wrapped URL renders as clickable link with bold formatting; URL in strip_formatting mode renders as plain clickable link; `/me` action with URL renders URL as clickable

### Implementation for User Story 1

- [x] T013 [US1] Add `.chat-link` CSS styles to `apps/retro_hex_chat_web/assets/css/dark-theme.css` — underline, distinct blue color fitting retro aesthetic, cursor pointer, hover state
- [x] T014 [US1] Extend `format_content/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — when `strip_formatting` is true: call `URLDetector.linkify/1` on stripped+escaped text; when false: call `URLDetector.linkify_html/1` on Formatter HTML output. Also update `/me` action rendering to use `format_content`.
- [x] T015 [US1] Run `mix format`, `mix credo --strict`, `mix dialyzer`, `mix test` — fix any issues

**Checkpoint**: Clickable URLs work in both channels and PMs. All acceptance scenarios for US1 are verifiable.

---

## Phase 4: User Story 2 — URL Catcher Window (Priority: P2)

**Goal**: Floating window aggregating all captured URLs with sortable table, channel filter dropdown, URL text search, and double-click to open. Updates in real-time as new messages arrive.

**Independent Test**: Send messages with URLs in multiple channels → open URL Catcher → verify all URLs appear with correct columns → filter by channel → search by URL text → double-click opens URL.

### Tests for User Story 2

- [x] T016 [P] [US2] Write unit tests for `CapturedURL` struct in `apps/retro_hex_chat/test/retro_hex_chat/chat/captured_url_test.exs` — cover: `new/1` creates struct with auto-generated id and nil preview_title; `set_preview_title/2` updates title; `filter_by_source/2` filters by channel/PM and nil returns all; `filter_by_url/2` case-insensitive URL text search; `sort_by/3` sorts by :url, :source, :posted_by, :timestamp in both :asc and :desc
- [x] T017 [P] [US2] Write LiveView tests for URL Catcher window in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_catcher_test.exs` — cover: window opens with `toggle_url_catcher` event; window shows table with URL/Channel/Posted By/Time columns; window closes on toggle; real-time update (new message with URL appears in open window); empty window shows appropriate message; retro styling classes present

### Implementation for User Story 2

- [x] T018 [US2] Implement `CapturedURL` struct in `apps/retro_hex_chat/lib/retro_hex_chat/chat/captured_url.ex` — defstruct with id, url, source, source_type, posted_by, timestamp, preview_title fields; `new/1`, `set_preview_title/2`, `filter_by_source/2`, `filter_by_url/2`, `sort_by/3` functions with `@spec` and `@type t`
- [x] T019 [US2] Add URL catcher assigns to ChatLive `assign_defaults` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — `url_catcher_entries: []`, `show_url_catcher: false`, `url_catcher_sort_column: :timestamp`, `url_catcher_sort_direction: :desc`, `url_catcher_filter_channel: nil`, `url_catcher_search_query: ""`
- [x] T020 [US2] Implement URL extraction in ChatLive `handle_info` for channel and PM messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — call `URLDetector.extract_urls/1` on message content, create `CapturedURL` entries, prepend to `@url_catcher_entries`
- [x] T021 [US2] Create `URLCatcherHook` JS in `apps/retro_hex_chat_web/assets/js/hooks/url_catcher_hook.js` — listen for `dblclick` on rows with `data-url` attribute, call `window.open(url, '_blank', 'noopener,noreferrer')`
- [x] T022 [US2] Register `URLCatcherHook` in `apps/retro_hex_chat_web/assets/js/hooks/index.js` (or app.js hooks object)
- [x] T023 [US2] Implement `URLCatcherWindow` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/url_catcher_window.ex` — floating retro window (absolute position, z-index 150, 500x350px); title bar with close button; filter dropdown + search input; sortable table with URL/Channel/Posted By/Time columns; status bar with entry count; `data-url` attribute on rows for hook; visibility controlled by `:visible` attribute
- [x] T024 [US2] Add event handlers to ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — `toggle_url_catcher`, `url_catcher_sort` (toggle column + direction), `url_catcher_filter` (set channel filter), `url_catcher_search` (set search query). Apply CapturedURL filter/sort before passing to component.
- [x] T025 [US2] Write LiveView tests for sort, filter, and search in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_catcher_test.exs` — cover: clicking column header sorts entries; clicking same header toggles direction; selecting channel filter shows only that channel's URLs; typing in search field filters by URL content; filter + search combined
- [x] T026 [US2] Render `URLCatcherWindow` in ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — pass filtered/sorted entries, sort state, filter state, search query, channel list, entry count
- [x] T027 [US2] Run `mix format`, `mix credo --strict`, `mix dialyzer`, `mix test` — fix any issues

**Checkpoint**: URL Catcher window displays all captured URLs with working sort, filter, and search. Real-time updates on new messages.

---

## Phase 5: User Story 3 — Inline Link Preview (Priority: P3)

**Goal**: Asynchronously fetch page titles for URLs and display as small plain-text previews near links in chat. Graceful degradation on errors. XSS-safe.

**Independent Test**: Send a message with a URL to a page with a known title → verify the title appears as preview text near the link. Send a URL to an unreachable page → verify no preview and no error.

### Tests for User Story 3

- [x] T028 [P] [US3] Write `LinkPreview` behaviour in `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview.ex` — define `@callback fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}`
- [x] T029 [P] [US3] Configure Mox for `LinkPreview` behaviour — define `RetroHexChat.Chat.LinkPreviewMock` in `apps/retro_hex_chat/test/support/mocks.ex`, add `Mox.defmock` call, configure application env for test
- [x] T030 [P] [US3] Write unit tests for `LinkPreview.Cache` in `apps/retro_hex_chat/test/retro_hex_chat/chat/link_preview/cache_test.exs` — cover: `get/1` returns `:miss` for uncached URL; `put/2` then `get/1` returns `{:ok, title}`; TTL expiry (1 hour) returns `:miss`; `mark_pending/1` then `pending?/1` returns true; `put/2` clears pending flag; error caching (5-min TTL); nil title stored correctly
- [x] T031 [P] [US3] Write unit tests for `LinkPreview.HTTP.fetch_title/1` in `apps/retro_hex_chat/test/retro_hex_chat/chat/link_preview/http_test.exs` — cover: extracts `<title>` from HTML; HTML-escapes title (XSS prevention); strips whitespace from title; truncates title > 200 chars; returns `{:error, :no_title}` when no title tag; returns `{:error, :not_html}` for non-HTML content-type; handles `<title>` with attributes; handles multiline title tags. Use `Bypass` or extract `parse_title/1` as pure function for testing.

### Implementation for User Story 3

- [x] T032 [US3] Implement `LinkPreview.Cache` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/cache.ex` — GenServer owning an ETS table; `get/1`, `put/2`, `pending?/1`, `mark_pending/1` public API; 1-hour TTL for success, 5-min TTL for errors; `start_link/1` for supervision
- [x] T033 [US3] Implement `LinkPreview.HTTP` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/http.ex` — `@behaviour Chat.LinkPreview`; `fetch_title/1` uses `Req.get/2` with 5-second timeout, max 3 redirects, read only first 50KB; parse `<title>` tag from response body; HTML-escape title; return typed error tuples
- [x] T034 [US3] Add `LinkPreview.Cache` and `{Task.Supervisor, name: RetroHexChat.LinkPreviewTasks}` to domain app supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- [x] T035 [US3] Add `.chat-link-preview` CSS styles to `apps/retro_hex_chat_web/assets/css/dark-theme.css` — small font, muted color, displayed below or beside the link, subtle appearance
- [x] T036 [US3] Write LiveView tests for async link preview in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_test.exs` — cover: message renders immediately without preview; preview appears after fetch completes (mock via send); no preview shown on error; title is HTML-escaped in display; preview updates CapturedURL entry in URL Catcher
- [x] T037 [US3] Implement async title fetch in ChatLive `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — on new message with URLs: check `LinkPreview.Cache` for each URL; if miss, `mark_pending` and spawn `Task.Supervisor.async_nolink` to fetch title; task sends `{:link_preview, url, result}` back to LiveView
- [x] T038 [US3] Implement `handle_info({:link_preview, url, result})` in ChatLive `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — on `{:ok, title}`: update cache, update CapturedURL entries with title, push preview to client; on `{:error, _}`: update cache with error, no UI change
- [x] T039 [US3] Add link preview rendering to ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — render `<span class="chat-link-preview">` with preview title below/beside links. Handle nil preview_title gracefully.
- [x] T040 [US3] Run `mix format`, `mix credo --strict`, `mix dialyzer`, `mix test` — fix any issues

**Checkpoint**: Link previews appear asynchronously for reachable pages. Errors degrade gracefully. XSS prevented.

---

## Phase 6: User Story 4 — URL Catcher Access via Menu and Keyboard (Priority: P4)

**Goal**: URL Catcher window accessible via menu bar "URL Catcher" item and Alt+U keyboard shortcut.

**Independent Test**: Press Alt+U → URL Catcher opens. Select "URL Catcher" from menu → window opens. Close and reopen → entries preserved.

### Tests for User Story 4

- [x] T041 [P] [US4] Write LiveView tests for menu bar and keyboard shortcut in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_catcher_test.exs` — cover: Alt+U opens URL Catcher window; Alt+U again closes it; menu bar "URL Catcher" item triggers toggle; close and reopen preserves entries; window has retro MDI styling

### Implementation for User Story 4

- [x] T042 [US4] Add "URL Catcher" menu item to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` — add item under Tools menu with `phx-click="toggle_url_catcher"` event
- [x] T043 [US4] Add Alt+U keyboard shortcut to ChatLive `window_keydown` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — match `%{"key" => "u", "altKey" => true}`, toggle `show_url_catcher` assign with sub-state cleanup (same pattern as Alt+B and Alt+H)
- [x] T044 [US4] Run `mix format`, `mix credo --strict`, `mix dialyzer`, `mix test` — fix any issues

**Checkpoint**: URL Catcher accessible via both menu and keyboard. All US4 acceptance scenarios pass.

---

## Phase 7: Polish & E2E Tests

**Purpose**: End-to-end coverage, edge case verification, data-testid attributes, final linter pass

- [x] T045 Add `data-testid` attributes to URL Catcher window elements (table, filter, search, rows, close button) and chat link elements (`<a class="chat-link">`) across `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/url_catcher_window.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T046 [P] Write E2E tests for clickable URLs in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_e2e_test.exs` — cover: send message with URL renders clickable link; URL with trailing period excludes period; multiple URLs in one message; long URL truncation visible; URL in PM also clickable
- [x] T047 [P] Write E2E tests for URL Catcher window in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_e2e_test.exs` — cover: open via Alt+U; table shows captured URLs with all columns; sort by column click; filter by channel dropdown; search by URL text; close and reopen preserves entries; new message adds entry in real-time; open via menu bar
- [x] T048 [P] Write E2E tests for link preview in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_e2e_test.exs` — cover: preview title appears near link; no preview for unreachable URL; preview title is escaped plain text
- [x] T049 [P] Write E2E test for session reset in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_url_e2e_test.exs` — cover: URL Catcher is empty on fresh connect (no persistence across sessions)
- [x] T050 Verify edge cases: URLs in system/service/error messages are NOT linkified (only :message and :action types); URL in `/me` action message IS linkified; URLs inside formatted text (bold, color) still detected; URL-only messages render entirely as a link
- [x] T051 Run full suite `make test.all` + `make lint` (format + credo + dialyzer) — fix any remaining issues

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — No dependencies on other stories
- **US2 (Phase 4)**: Depends on Phase 2 — Can run in parallel with US1 (but benefits from US1's CSS)
- **US3 (Phase 5)**: Depends on Phase 2 — Can run in parallel with US1/US2
- **US4 (Phase 6)**: Depends on US2 (Phase 4) — window must exist before adding access methods
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Phase 2 only → MVP. Delivers clickable links immediately.
- **US2 (P2)**: Phase 2 only → Adds URL aggregation window. Optionally uses US1 CSS.
- **US3 (P3)**: Phase 2 only → Adds link previews. Independent of US2.
- **US4 (P4)**: Phase 4 (US2) → Adds menu + keyboard access to the US2 window.

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD per Constitution IV)
- Domain modules before web layer integration
- Component implementation before ChatLive wiring
- Linter pass after each story phase

### Parallel Opportunities

- **Phase 2**: T003 + T004 (extract_urls tests) parallel with T006 + T007 (linkify tests)
- **Phase 3**: T010 + T011 + T012 (US1 tests) all parallel
- **Phase 4**: T016 + T017 (US2 tests) parallel
- **Phase 5**: T028 + T029 + T030 + T031 (US3 behaviour + tests) all parallel
- **Phase 6**: T041 (US4 tests) runs standalone
- **Phase 7**: T046 + T047 + T048 + T049 (E2E tests) all parallel
- **Cross-story**: US1, US2, US3 can run in parallel after Phase 2 (different files)

---

## Parallel Example: Phase 2 (Foundational)

```text
# Parallel batch 1 — all test files:
Task T003: "Unit tests for extract_urls/1"
Task T004: "Property tests for extract_urls/1"
Task T006: "Unit tests for linkify/1"
Task T007: "Unit tests for linkify_html/1"

# Sequential — implementation (depends on tests existing):
Task T005: "Implement extract_urls/1"
Task T008: "Implement linkify/1 and linkify_html/1"
Task T009: "Linter pass"
```

## Parallel Example: User Story 2

```text
# Parallel batch 1 — tests + struct:
Task T016: "Unit tests for CapturedURL"
Task T017: "LiveView tests for URL Catcher window"

# Sequential — implementation:
Task T018: "Implement CapturedURL struct" (depends on T016)
Task T019: "Add URL catcher assigns to ChatLive"
Task T020: "URL extraction in handle_info"
Task T021-T022: "URLCatcherHook JS + registration"
Task T023: "URLCatcherWindow component"
Task T024: "Event handlers in ChatLive"
Task T025: "Sort/filter/search LiveView tests"
Task T026: "Render component in template"
Task T027: "Linter pass"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (URLDetector engine)
3. Complete Phase 3: User Story 1 (clickable URLs)
4. **STOP and VALIDATE**: Send URLs in chat → verify clickable links
5. This alone delivers significant user value

### Incremental Delivery

1. Setup + Foundational → URLDetector ready
2. Add US1 → Clickable URLs in chat → **MVP!**
3. Add US2 → URL Catcher window with sort/filter/search
4. Add US4 → Menu + keyboard access for URL Catcher
5. Add US3 → Link previews (async page titles)
6. Polish → E2E tests, edge cases, data-testid attrs

### Recommended Execution Order

US1 → US2 → US4 → US3 → Polish

US4 is moved before US3 because it's a small addition to the US2 window (menu + shortcut) and completes the URL Catcher story before adding the more complex link preview system.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No database migrations — all data is in-memory
- Constitution IV mandates TDD: tests before implementation
- Req dependency is transitive but must be explicit for direct usage
- Link preview uses Mox for testability (Constitution V)
- URL Catcher is session-scoped — resets on reconnect, no persistence
