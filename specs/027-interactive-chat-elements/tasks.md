# Tasks: Interactive Chat Elements

**Input**: Design documents from `/specs/027-interactive-chat-elements/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per Constitution Principle IV (TDD is non-negotiable).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create new files and shared utilities that all user stories depend on

- [x] T001 [P] Create `interactive.js` lib module with shared utility functions (click-vs-drag detection, tooltip create/remove, context menu open flag, viewport boundary repositioning) in `apps/retro_hex_chat_web/assets/js/lib/interactive.js`
- [x] T002 [P] Create `hover-card.css` with retro-styled tooltip and nick hover card styles in `apps/retro_hex_chat_web/assets/css/hover-card.css` and add import to `apps/retro_hex_chat_web/assets/css/app.css` in the Components layer
- [x] T003 [P] Create `hover_events.ex` event handler module with initial structure (module, `handle_event/3` function heads that return `{:cont, socket}` for unmatched events) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- [x] T004 Attach `hover_events` hook in `ChatLive.attach_all_hooks/1` and add `hover_card` default assign to `ChatLive.mount/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: Shared infrastructure ready — user story implementation can begin

---

## Phase 2: User Story 1 — Clickable URLs with Hover Tooltip (Priority: P1) 🎯 MVP

**Goal**: URLs in chat messages show page title on hover (via native `title` attribute) and open in new tab on click. Pointer cursor and underline on hover.

**Independent Test**: Send a message containing a URL, verify hover shows tooltip with page title, click opens new tab.

### Tests for User Story 1

- [x] T005 [P] [US1] Write JS tests for `interactive.js` utility functions (`isClickNotDrag`, `createTooltip`, `removeTooltip`, `isContextMenuOpen`) in `apps/retro_hex_chat_web/assets/test/lib/interactive.test.js`

### Implementation for User Story 1

- [x] T006 [US1] Update the existing `link_preview` event handler in `scroll_hook.js` to also set the `title` attribute of matching `<a>` tags to the fetched page title (so native browser tooltip shows title instead of raw URL) in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T007 [US1] Verify `.chat-link` CSS hover styles include pointer cursor and underline-on-hover (already present — confirm and enhance if needed) in `apps/retro_hex_chat_web/assets/css/chat.css`

**Checkpoint**: URLs show page title tooltip on hover and open in new tab on click

---

## Phase 3: User Story 2 — Clickable Channel Names (Priority: P2)

**Goal**: Channel names in chat show tooltip with user count on hover. Single-click joins or switches to the channel.

**Independent Test**: Send a message mentioning `#channel`, hover to see user count tooltip, click to join/switch.

### Tests for User Story 2

- [x] T008 [P] [US2] Write JS tests for channel tooltip creation and removal (tooltip text formatting, cache expiry logic) in `apps/retro_hex_chat_web/assets/test/lib/interactive.test.js`
- [x] T009 [P] [US2] Write LiveView test for `"channel_hover"` event (returns channel count and joined status) and `"channel_click"` event (joins if not joined, switches if already joined) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/hover_events_test.exs`

### Implementation for User Story 2

- [x] T010 [US2] Implement `handle_event("channel_hover", ...)` in `hover_events.ex`: query `Server.get_state/1` for member count, check if user is already in channel, push `"channel_tooltip"` event with `{channel, count, joined}` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- [x] T011 [US2] Implement `handle_event("channel_click", ...)` in `hover_events.ex`: if channel is in `session.channels` call `switch_channel`, otherwise call `ChannelHelper.join_channel/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- [x] T012 [US2] Add channel hover/click/tooltip event listeners in `scroll_hook.js`: mouseenter on `.chat-channel-link` pushes `"channel_hover"`, mouseleave removes tooltip, click pushes `"channel_click"` (with click-vs-drag check using `interactive.js`), handleEvent `"channel_tooltip"` renders positioned tooltip in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T013 [US2] Verify channel name punctuation trimming: ensure `linkify_channels/1` in `formatter.ex` / `chat_live.ex` excludes trailing punctuation (`.` `,` `!` `?` `;` `:`) from `data-channel` attribute. Add unit tests for edge cases in `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`

**Checkpoint**: Channel names show user count tooltip on hover and join/switch on click

---

## Phase 4: User Story 3 — Clickable Nicks with Hover Card (Priority: P3)

**Goal**: Nicks in chat messages show a hover card with whois data after 500ms idle hover. Single-click inserts nick into input. Double-click opens PM.

**Independent Test**: Hover over a nick for 500ms to see hover card with user info. Click to insert nick. Double-click to open PM.

### Tests for User Story 3

- [x] T014 [P] [US3] Write JS tests for nick hover debounce logic (timer start/reset/cancel, 500ms idle detection) in `apps/retro_hex_chat_web/assets/test/lib/interactive.test.js`
- [x] T015 [P] [US3] Write LiveView tests for `"nick_hover"` event (returns whois data, suppresses own nick), `"nick_hover_dismiss"` (resets assign), and `"nick_dblclick"` (opens PM) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/hover_events_test.exs`

### Implementation for User Story 3

- [x] T016 [US3] Create `hover_card.ex` function component: render nick hover card with retro window styling (`title-bar`, `window-body`), showing nickname, hostname, online duration, channels list, and interaction hints text. Include loading state variant. in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/hover_card.ex`
- [x] T017 [US3] Add nick hover card component to `chat_live.html.heex` template: render `<HoverCard.nick_hover_card>` conditionally when `@hover_card.visible` is true, positioned absolutely at `@hover_card.x`/`@hover_card.y` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T018 [US3] Implement `handle_event("nick_hover", ...)` in `hover_events.ex`: validate nick is not own nick (FR-014), gather whois data using `Whois.gather_whois_data/4` pattern, format online duration, update `hover_card` assign with loading→data transition in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- [x] T019 [US3] Implement `handle_event("nick_hover_dismiss", ...)` and `handle_event("nick_dblclick", ...)` in `hover_events.ex`: dismiss resets `hover_card` assign to default; dblclick calls `PM.open_pm_conversation/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- [x] T020 [US3] Add nick hover/click/dblclick event listeners in `scroll_hook.js`: mouseenter on `.chat-nick` starts 500ms idle timer (reset on mousemove, cancel on mouseleave), timer fires pushEvent `"nick_hover"`, mouseleave pushes `"nick_hover_dismiss"`. Click inserts "Nick: " using `insertAtCursor` from `input.js` (client-only, no server event). Dblclick pushes `"nick_dblclick"` in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T021 [US3] Style the nick hover card in `hover-card.css`: retro window borders, compact layout, channel list, interaction hints in muted text, loading spinner/placeholder, viewport boundary repositioning in `apps/retro_hex_chat_web/assets/css/hover-card.css`

**Checkpoint**: Nick hover card shows whois data after 500ms. Click inserts nick. Double-click opens PM.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, context menu coexistence, help documentation, and CI validation

- [x] T022 Add context menu coexistence: export `contextMenuOpen` flag from context menu system, import in `interactive.js`, check flag before all hover/click handlers. Set flag in `scroll_hook.js` when context menu opens (existing `"contextmenu"` listener), clear when closed in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js` and `apps/retro_hex_chat_web/assets/js/lib/interactive.js`
- [x] T023 Add nick change hover card dismissal: in the existing nick change PubSub handler, check if `socket.assigns.hover_card.nick` matches the old nick and push `"dismiss_hover_card"` event if so. Handle event client-side in `scroll_hook.js` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex` and `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T024 Add text selection suppression: ensure nick hover timer cancels on mousedown (text selection start), and click handlers check `window.getSelection().toString()` plus mouse movement delta before triggering actions (FR-015, FR-020) in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T025 Add viewport mouseleave cleanup: listen for `mouseleave` on `document.documentElement`, remove any active tooltips and cancel pending hover timers (FR-019) in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [x] T026 Add help topic "Interactive Chat Elements" to HelpTopics in the "Features" category covering URL tooltips, channel click-to-join, nick hover cards, and click/double-click actions. Add "See Also" cross-references to existing related topics in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [x] T027 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **User Story 1 (Phase 2)**: Depends on T001, T002 (shared JS lib and CSS)
- **User Story 2 (Phase 3)**: Depends on T001, T002, T003, T004 (shared infrastructure + hover_events module)
- **User Story 3 (Phase 4)**: Depends on T001, T002, T003, T004 (shared infrastructure + hover_events module)
- **Polish (Phase 5)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Independent — only needs shared JS lib from Phase 1
- **User Story 2 (P2)**: Independent — needs hover_events.ex from Phase 1
- **User Story 3 (P3)**: Independent — needs hover_events.ex and hover_card.ex (created in this phase)
- User stories can be implemented sequentially (P1 → P2 → P3) or in parallel after Phase 1

### Within Each User Story

- Tests MUST be written first (TDD — Constitution Principle IV)
- Server-side event handlers before client-side listeners
- Client-side listeners wire to server events
- CSS styles can be done in parallel with logic

### Parallel Opportunities

- T001, T002, T003 can all run in parallel (different files)
- Within US2: T008 and T009 (tests) can run in parallel
- Within US3: T014 and T015 (tests) can run in parallel
- Within US3: T016 (component) and T018/T019 (event handlers) work on different files
- After all stories: T022–T026 (polish) are mostly independent files

---

## Parallel Example: Phase 1 Setup

```bash
# All three setup tasks can run in parallel:
Task: "T001 — Create interactive.js lib module"
Task: "T002 — Create hover-card.css"
Task: "T003 — Create hover_events.ex module"
```

## Parallel Example: User Story 3 Tests

```bash
# Both test tasks can run in parallel:
Task: "T014 — JS tests for nick hover debounce"
Task: "T015 — LiveView tests for nick hover events"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T004)
2. Complete Phase 2: User Story 1 (T005–T007)
3. **STOP and VALIDATE**: URLs show page title tooltip, click opens tab
4. This alone delivers value — URLs become obviously interactive

### Incremental Delivery

1. Setup → US1 (URLs) → Validate → **MVP deployed**
2. Add US2 (Channels) → Validate → Channel click-to-join works
3. Add US3 (Nicks) → Validate → Nick hover cards and click actions work
4. Polish (T022–T027) → Full CI validation → Feature complete

### Sequential Developer Strategy

1. Phase 1 Setup (T001–T004) — 4 tasks
2. US1 URLs (T005–T007) — 3 tasks → validate
3. US2 Channels (T008–T013) — 6 tasks → validate
4. US3 Nicks (T014–T021) — 8 tasks → validate
5. Polish (T022–T027) — 6 tasks → full CI

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All new Elixir functions MUST have `@spec` annotations (Constitution VI)
- JS follows "hook = wiring, lib = logic" pattern (Constitution IV)
- No new database migrations — all data from in-memory sources
- Nick hover card uses retro window styling for design fidelity (Constitution VIII)
- Help topic required for feature completeness (Constitution XI)
