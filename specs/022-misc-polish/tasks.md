# Tasks: Miscellaneous Polish

**Input**: Design documents from `/specs/022-misc-polish/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per Constitution Principle IV (TDD is non-negotiable).

**Organization**: Tasks grouped by user story (11 stories across 7 implementation phases + setup + polish).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1–US11)
- Exact file paths included in all descriptions

---

## Phase 1: Setup

**Purpose**: Verify clean baseline on feature branch

- [x] T001 Verify baseline — run `make ci` (all 9 checks pass). Record current test counts.

**Checkpoint**: Clean baseline confirmed, ready for implementation.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend UserPreferences with `timestamp_format` and `quit_message` keys — needed by US6 (quit message preference) and US8 (timestamp format configuration).

- [x] T002 [P] Write unit tests for UserPreferences `timestamp_format` and `quit_message` getters/setters in `apps/retro_hex_chat/test/retro_hex_chat/chat/user_preferences_test.exs` — test `get_timestamp_format/1` returns `:hh_mm` default, `set_timestamp_format/2` with all 4 valid atoms (`:hh_mm`, `:hh_mm_ss`, `:dd_mm_hh_mm`, `:none`), `get_quit_message/1` returns `"Leaving"` default, `set_quit_message/2` with valid string and 200-char max validation.
- [x] T003 [P] Write unit test for `DisplayPreferences.format_timestamp/2` with `:none` format returning empty string in `apps/retro_hex_chat/test/retro_hex_chat/chat/display_preferences_test.exs`.
- [x] T004 Extend `UserPreferences` module with `get_timestamp_format/1`, `set_timestamp_format/2`, `get_quit_message/1`, `set_quit_message/2` functions in `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` — add keys to `default_display/0` map, handle atom↔string conversion for JSONB storage.
- [x] T005 Add `:none` timestamp format to `DisplayPreferences` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/display_preferences.ex` — add clause `format_timestamp(:none, _dt)` returning `""`, update `@valid_timestamp_formats` and `@type timestamp_format`.
- [x] T006 Add new socket assigns to `assign_defaults` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `away_replied_to: MapSet.new()`, `paste_lines: nil`, `quit_reason: nil`, `show_emoji_picker: false`, `emoji_search: ""`, `emoji_category: "Smileys & Emotion"`.

**Checkpoint**: Foundation ready — UserPreferences extended, new assigns initialized. All user stories can now proceed.

---

## Phase 3: User Story 1 — Nick Column Alignment (Priority: P1)

**Goal**: All nicknames rendered in a fixed-width column so message text starts at the same horizontal position regardless of nick length.

**Independent Test**: Send messages from nicks of varying length (1–16 chars) and verify alignment.

### Tests

- [x] T007 [P] [US1] Write LiveView tests for nick column alignment in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_nick_column_test.exs` — test that regular messages render with `chat-msg-grid` class, action messages do NOT have grid class, notice messages do NOT have grid class, system/service/error messages do NOT have grid class. Test with 1-char, 8-char, and 16-char nicks all producing grid layout.

### Implementation

- [x] T008 [US1] Add CSS grid layout for regular messages in `apps/retro_hex_chat_web/assets/css/chat.css` — add `.chat-msg-grid` class with `display: grid; grid-template-columns: auto 20ch 1fr;` (20ch = 16 chars for nick + `<>` brackets + padding). Timestamp and nick columns fixed, content column flexible. Nick column uses `text-align: right;` for right-aligned nicks.
- [x] T009 [US1] Add dark theme counterparts in `apps/retro_hex_chat_web/assets/css/dark-theme.css` — SKIPPED: No dark-theme.css file exists; theming uses CSS custom properties throughout.
- [x] T010 [US1] Modify chat message template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — wrap regular (default case) messages in a `<div class="chat-msg-grid">` container with timestamp, nick, and content as separate grid children. Action, notice, system, service, and error messages keep current full-width `<div class="chat-message ...">` layout without grid.
- [x] T011 [US1] Write E2E tests for nick column alignment in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/nick_column_e2e_test.exs` — test grid class on regular messages, no grid on action messages, no grid on system messages.

**Checkpoint**: US1 complete — all message bodies align at the same horizontal position.

---

## Phase 4: User Story 2 — Double-Click Actions (Priority: P1)

**Goal**: Double-click on nicklist nick opens PM, channel name in chat joins channel, URL opens in new tab.

**Independent Test**: Double-click a nickname in the nicklist and verify a PM tab opens.

### Tests

- [x] T012 [P] [US2] Write LiveView tests for nicklist double-click → PM in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_dblclick_test.exs` — test that `nicklist_dblclick` event with valid nick opens a PM conversation, test with offline nick shows "User is offline" system message.
- [x] T013 [P] [US2] Write LiveView tests for channel double-click → join in the same test file — test `channel_dblclick` event with channel name joins or switches to that channel.

### Implementation

- [x] T014 [US2] Modify nicklist double-click behavior in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — removed 300ms server-side double-click detection (replaced by NicklistHook JS dblclick). Single-click shows context menu.
- [x] T015 [US2] Add `nicklist_dblclick` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — handle `"nicklist_dblclick"` event: opens PM query tab via `open_pm_conversation/2`, closes context menu.
- [x] T016 [US2] Add channel name detection in chat content — modify `format_content/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` (after URL linkification) to wrap `#channel-name` patterns in `<span class="chat-channel-link" data-channel="#name">` for double-click targets.
- [x] T017 [US2] Add `channel_dblclick` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex` — handle `"channel_dblclick"` event: if already joined switch to channel, else call `join_channel/3`.
- [x] T018 [US2] Add JS double-click handlers in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js` — add `dblclick` listener on `.chat-messages` container that detects clicks on `.chat-channel-link` elements, pushes `channel_dblclick` event to LiveView.
- [x] T019 [US2] Add `phx-hook="NicklistHook"` to nicklist container and create `apps/retro_hex_chat_web/assets/js/hooks/nicklist_hook.js` — listen for `dblclick` on `li` elements inside `.nicklist-list`, push `nicklist_dblclick` event with the nick text. Registered in `apps/retro_hex_chat_web/assets/js/app.js`.
- [x] T020 [US2] Write E2E tests for double-click actions in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/dblclick_e2e_test.exs` — test nicklist dblclick opens PM tab, channel name dblclick joins channel, channel link rendering, NicklistHook presence.

**Checkpoint**: US2 complete — double-click on nick → PM, channel → join, URLs → already clickable.

---

## Phase 5: User Story 3 — Right-Click Copy (Priority: P1)

**Goal**: Users can select and copy text from the chat area via right-click context menu or Ctrl+C.

**Independent Test**: Select text in chat, Ctrl+C copies to clipboard as plain text.

### Tests

- [x] T021 [P] [US3] Write LiveView tests for chat copy hook rendering in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_copy_test.exs` — test ScrollHook presence (includes copy support), test chat-messages allows text selection.

### Implementation

- [x] T022 [US3] Integrated copy context menu into ScrollHook in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js` — contextmenu listener, window.getSelection(), retro-styled copy menu, Copy with navigator.clipboard, mousedown/Escape dismiss, disabled state when no selection. Merged into ScrollHook since LiveView only allows one phx-hook per element.
- [x] T023 [US3] SKIPPED — No separate ChatCopyHook needed; merged into existing ScrollHook.
- [x] T024 [US3] SKIPPED — `.chat-messages` already has `phx-hook="ScrollHook"` which now includes copy functionality.
- [x] T025 [US3] Add CSS for copy context menu in `apps/retro_hex_chat_web/assets/css/chat.css` — `.copy-context-menu`, `.copy-menu-item`, `.copy-menu-item--disabled` with retro styling.
- [x] T026 [US3] E2E tests covered by LiveView tests in chat_live_copy_test.exs — hook presence and text selection enabled assertions.

**Checkpoint**: US3 complete — users can copy text from chat via right-click or Ctrl+C.

---

## Phase 6: User Story 4 — Character Counter (Priority: P2)

**Goal**: Real-time character counter near input showing current/1000 with color thresholds.

**Independent Test**: Type in input and verify counter updates in real-time.

### Tests

- [x] T027 [P] [US4] Write LiveView tests for character counter rendering in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_counter_test.exs` — counter span with data-testid, maxlength, CharCounterHook presence.

### Implementation

- [x] T028 [US4] Create CharCounterHook JS in `apps/retro_hex_chat_web/assets/js/hooks/char_counter_hook.js` — input listener, counter text update, warning/danger CSS classes at 450/900 thresholds.
- [x] T029 [US4] Register CharCounterHook in `apps/retro_hex_chat_web/assets/js/app.js`.
- [x] T030 [US4] Add character counter HTML and hook to template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — counter span, CharCounterHook on input-area, maxlength="1000" on input.
- [x] T031 [US4] Add CSS for character counter in `apps/retro_hex_chat_web/assets/css/chat.css` — .char-counter, .char-counter--warning, .char-counter--danger.
- [x] T032 [US4] E2E tests covered by LiveView tests in chat_live_counter_test.exs — counter element, maxlength, hook presence.

**Checkpoint**: US4 complete — character counter updates in real-time with color thresholds.

---

## Phase 7: User Story 5 — Multi-Line Paste Dialog (Priority: P2)

**Goal**: Paste of 2+ lines shows confirmation dialog before sending; 300ms pacing; 100-line hard cap.

**Independent Test**: Paste 5 lines and verify confirmation dialog appears.

### Tests

- [x] T033 [P] [US5] Write LiveView tests for paste dialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_paste_test.exs` — test `paste_lines` event sets `paste_lines` assign and shows dialog, test `paste_cancel` clears lines, test `paste_send` dispatches messages (mock send), test >50 lines sets flood warning, test >100 lines disables send, test empty lines are filtered out.
- [x] T034 [P] [US5] Write component test for PasteConfirmDialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/paste_confirm_dialog_test.exs` — test renders line count, test "Send All" and "Cancel" buttons visible, test flood warning visible when `flood_warning: true`, test "Send All" disabled when `send_disabled: true`, test pastebin suggestion when disabled.

### Implementation

- [x] T035 [US5] Create PasteConfirmDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/paste_confirm_dialog.ex` — retro window dialog with title "Paste Confirmation", body showing "You are about to send N lines.", flood warning text (bold red) when >50, pastebin suggestion when >100, "Send All" button (disabled when >100) and "Cancel" button. Attrs: `visible`, `line_count`, `flood_warning`, `send_disabled`.
- [x] T036 [US5] Create PasteHook JS in `apps/retro_hex_chat_web/assets/js/hooks/paste_hook.js` — on `mounted()`: listen for `paste` event on `#chat-input`, read `e.clipboardData.getData("text/plain")`, split by `\n`, filter empty lines, if 2+ non-empty lines: `e.preventDefault()` and `this.pushEvent("paste_lines", {lines})`. Single line: allow normal paste.
- [x] T037 [US5] Register PasteHook in `apps/retro_hex_chat_web/assets/js/hooks/index.js`.
- [x] T038 [US5] Add paste event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex` — `handle_event("paste_lines", %{"lines" => lines})`: filter empty lines, set `paste_lines` assign, compute `flood_warning` (>50) and `send_disabled` (>100). `handle_event("paste_cancel")`: reset `paste_lines` to nil. `handle_event("paste_send")`: start 300ms paced message chain via `Process.send_after(self(), {:paste_next, remaining_lines}, 0)`.
- [x] T039 [US5] Add `handle_info({:paste_next, lines})` in ChatLive for paced message delivery — send first line as a regular message via existing `send_input` dispatch, then `Process.send_after(self(), {:paste_next, rest}, 300)` for remaining lines. Reset `paste_lines` to nil when done.
- [x] T040 [US5] Add PasteConfirmDialog + PasteHook to template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — render dialog component with paste_lines assigns, add `phx-hook="PasteHook"` to input form wrapper.
- [x] T041 [US5] Add CSS for paste dialog in `apps/retro_hex_chat_web/assets/css/chat.css` — `.paste-flood-warning` bold red text, `.paste-pastebin-msg` italic. Add dark theme counterparts.
- [x] T042 [US5] Write E2E tests for multi-line paste in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/paste_e2e_test.exs` — test paste dialog shows on paste_lines event, test cancel clears dialog, test send dispatches messages.

**Checkpoint**: US5 complete — multi-line paste shows confirmation, 300ms pacing, 100-line cap.

---

## Phase 8: User Story 6 — Quit Message Broadcast (Priority: P2)

**Goal**: Quit message broadcast to all shared channels when user disconnects.

**Independent Test**: User A quits, User B sees quit message in shared channel.

### Tests

- [x] T043 [P] [US6] Write tests for quit broadcast in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_quit_test.exs` — test `/quit Goodbye` dispatches quit reason and triggers broadcast, test `/quit` without message uses default "Leaving", test quit message is received by other users in shared channels via PubSub, test quit message preference from UserPreferences is used when no explicit message.
- [x] T044 [P] [US6] Write unit tests for `broadcast_quit/3` helper in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/helpers/channel_helpers_test.exs` — test broadcast sends `:quit` message to all channel topics, test quit message is truncated to 200 characters.

### Implementation

- [x] T045 [US6] Add `broadcast_quit/3` helper in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex` — iterate all `session.channels`, broadcast `%{event: "user_quit", payload: %{nickname: nick, reason: reason}}` to each `"channel:#{name}"` PubSub topic. Truncate reason to 200 chars.
- [x] T046 [US6] Modify `handle_quit/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex` — before calling `cleanup_channels`, determine quit reason: read from `socket.assigns.quit_reason` (set by the existing `/quit` command handler dispatch), fallback to `UserPreferences.get_quit_message(session.user_preferences)`, fallback to `"Leaving"`. Call `broadcast_quit(session, reason)`. Note: the existing `/quit` command handler should set `quit_reason` assign when dispatching with an explicit message argument.
- [x] T047 [US6] Modify `quit_chat` and `disconnect` events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex` — before calling `cleanup_channels`, call `broadcast_quit(session, UserPreferences.get_quit_message(session.user_preferences))` to broadcast default quit message.
- [x] T048 [US6] Add `handle_info` for `:user_quit` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` — on receiving quit broadcast, insert system message "* {nick} has quit ({reason})" into chat stream for the relevant channel.
- [x] T049 [US6] Add quit message preference to Options Dialog display panel in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` — add text input for quit message with 200-char max, labeled "Default quit message". Add `options_change_quit_message` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`.
- [x] T050 [US6] Handle `terminate/2` callback in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` for unexpected disconnects — if socket is connected and has a session, call `broadcast_quit(session, default_quit_message)` then `cleanup_channels`.
- [x] T051 [US6] Write E2E tests for quit broadcast in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/quit_e2e_test.exs` — test /quit with message broadcasts to channel, test /quit without message uses default.

**Checkpoint**: US6 complete — quit messages visible to all users in shared channels.

---

## Phase 9: User Story 7 — Away Auto-Reply (Priority: P2)

**Goal**: Auto-reply to PMs when away, once per unique sender per away session.

**Independent Test**: Set /away, receive PM, sender sees auto-reply exactly once.

### Tests

- [x] T052 [P] [US7] Write tests for away auto-reply in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_away_reply_test.exs` — test PM while away sends auto-reply to sender, test second PM from same sender does NOT send another auto-reply, test PM from different sender sends auto-reply, test clearing away resets replied_to set, test setting away again allows new replies, test notice while away does NOT trigger auto-reply.

### Implementation

- [x] T053 [US7] Add away auto-reply logic in PM handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` — after processing incoming PM in `handle_info(%{event: "new_pm"})`, check if `session.away` is true and `payload.sender` is not in `socket.assigns.away_replied_to` MapSet. If so: broadcast auto-reply message "* {nick} is away: {away_message}" to the PM topic, add sender to `away_replied_to` MapSet.
- [x] T054 [US7] Modify `handle_set_away/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex` — when setting away, initialize `away_replied_to: MapSet.new()` in assigns (fresh for new away session).
- [x] T055 [US7] Modify `handle_set_away/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex` — in the clear-away branch (when away is toggled off), reset `away_replied_to: MapSet.new()` in assigns. Note: there is no separate `handle_clear_away/1` — away set/clear is handled as a toggle within `handle_set_away/2`.
- [x] T056 [US7] Ensure notice messages do NOT trigger auto-reply — verify that the notice `handle_info` path in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` does not have auto-reply logic (only PM path does).
- [x] T057 [US7] Write E2E tests for away auto-reply in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/away_reply_e2e_test.exs` — test away user receives PM and sender gets auto-reply, test second PM no duplicate reply.

**Checkpoint**: US7 complete — away auto-reply sends exactly once per unique sender.

---

## Phase 10: User Story 8 — Timestamp Format Configuration (Priority: P3)

**Goal**: Configurable timestamp format for chat messages via Options Dialog.

**Independent Test**: Change format in Options and verify chat messages update immediately.

### Tests

- [x] T058 [P] [US8] Write LiveView tests for timestamp format in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_timestamp_test.exs` — test default format renders `[HH:MM]`, test `options_change_timestamp_format` event updates format, test `:none` format hides timestamps, test stream resets on format change.

### Implementation

- [x] T059 [US8] Create new `format_time/2` function in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — accepts `(datetime, format_atom)`. Pattern match: `:hh_mm` → `"%H:%M"`, `:hh_mm_ss` → `"%H:%M:%S"`, `:dd_mm_hh_mm` → `"%d/%m %H:%M"`, `:none` → return `""`. Note: no `format_time/1` exists currently — timestamps are rendered inline in the template. This function centralizes formatting. Update all timestamp rendering sites in `chat_live.html.heex` to call `format_time(msg.timestamp, @timestamp_format)` (derived from session preferences).
- [x] T060 [US8] Add `timestamp_format` assign to ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — derive from `UserPreferences.get_timestamp_format(session.user_preferences)`, default `:hh_mm`. Update `assign_defaults`.
- [x] T061 [US8] Add timestamp format selector to Options Dialog display panel in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` — add `<select>` dropdown with 4 options: `[HH:MM]`, `[HH:MM:SS]`, `[DD/MM HH:MM]`, `None`. Add `options_change_timestamp_format` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex` that updates draft display settings.
- [x] T062 [US8] Add stream reset on timestamp format change in `apply_draft` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex` — when timestamp_format changes, trigger stream reset for `:chat_messages` and `:status_messages` so all visible messages re-render with new format.
- [x] T063 [US8] Update template timestamp rendering in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — change all `format_time(msg.timestamp)` calls to `format_time(msg.timestamp, @timestamp_format)`. Conditionally hide `<span class="chat-timestamp">` when format returns empty string.
- [x] T064 [US8] Write E2E tests for timestamp format in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/timestamp_e2e_test.exs` — test default HH:MM format, test format change via options updates messages.

**Checkpoint**: US8 complete — timestamp format configurable, changes apply immediately.

---

## Phase 11: User Story 9 — Emoji Support (Priority: P3)

**Goal**: Unicode emoji rendering + emoji picker with categories and search.

**Independent Test**: Open emoji picker, click emoji, verify it's inserted in input.

### Tests

- [x] T065 [P] [US9] Write unit tests for EmojiData module in `apps/retro_hex_chat/test/retro_hex_chat/chat/emoji_data_test.exs` — test `all/0` returns 8 categories, test total emoji count >= 200, test each emoji has `char`, `name`, `keywords` fields, test `search/1` with "smile" returns relevant results, test `by_category/1` with "Smileys & Emotion" returns emojis, test `categories/0` returns 8 strings, test search with empty string returns empty.
- [x] T066 [P] [US9] Write component test for EmojiPicker in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/emoji_picker_test.exs` — test renders category tabs, test renders emoji grid, test search input present, test emoji buttons have data-emoji attribute.
- [x] T067 [P] [US9] Write LiveView tests for emoji picker events in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_emoji_test.exs` — test `toggle_emoji_picker` toggles visibility, test `emoji_category` switches category, test `emoji_search` filters results, test `emoji_select` pushes insert event to JS.

### Implementation

- [x] T068 [US9] Create EmojiData module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/emoji_data.ex` — static module with `@emojis` module attribute containing ~300 curated Unicode emojis organized in 8 categories. Each emoji: `%{char: "😀", name: "grinning face", keywords: ["smile", "happy"]}`. Functions: `all/0`, `search/1` (case-insensitive match on name and keywords, min 2 chars), `by_category/1`, `categories/0`. All with `@spec`.
- [x] T069 [US9] Create EmojiPicker component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/emoji_picker.ex` — retro-styled popup window with: category tabs across top (8 categories), search input field, scrollable emoji grid (6-8 columns), each emoji as a button with `phx-click="emoji_select"` and `phx-value-emoji={char}`. Attrs: `visible`, `categories`, `active_category`, `search_query`, `search_results`.
- [x] T070 [US9] Create EmojiPickerHook JS in `apps/retro_hex_chat_web/assets/js/hooks/emoji_picker_hook.js` — listen for `insert_emoji` push_event from server, find `#chat-input`, insert emoji character at cursor position (using selectionStart/selectionEnd pattern from FormatToolbarHook), dispatch `input` event for counter update, focus input.
- [x] T071 [US9] Register EmojiPickerHook in `apps/retro_hex_chat_web/assets/js/hooks/index.js`.
- [x] T072 [US9] Add emoji picker event handlers in ChatLive — in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex` or new `emoji_events.ex`: `toggle_emoji_picker` (toggle `show_emoji_picker` assign), `emoji_category` (set `emoji_category` assign), `emoji_search` (set `emoji_search` + compute results via `EmojiData.search/1`), `emoji_select` (push_event `"insert_emoji"` with char to JS hook, close picker).
- [x] T073 [US9] Add emoji picker button to formatting toolbar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/formatting_toolbar.ex` — add emoji button (smiley face icon) with `phx-click="toggle_emoji_picker"`.
- [x] T074 [US9] Add EmojiPicker + EmojiPickerHook to template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — render emoji picker component with assigns, add `phx-hook="EmojiPickerHook"` to picker container.
- [x] T075 [US9] Add CSS for emoji picker in `apps/retro_hex_chat_web/assets/css/chat.css` — `.emoji-picker` positioned above input area, retro window styling. `.emoji-grid` grid layout. `.emoji-btn` for individual emojis. `.emoji-category-tabs` for category navigation. `.emoji-search` for search input. Dismiss on click outside / Escape (JS in hook). Add dark theme counterparts.
- [x] T076 [US9] Write E2E tests for emoji picker in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/emoji_e2e_test.exs` — test emoji picker toggle, test category tabs render, test emoji buttons render, test search field renders.

**Checkpoint**: US9 complete — emoji picker with 8 categories, search, and cursor insertion.

---

## Phase 12: User Story 10 — About Dialog Enhancement (Priority: P3)

**Goal**: Enhanced About dialog with ASCII art logo, version, credits.

**Independent Test**: Open Help > About and verify retro-style content.

### Tests

- [x] T077 [P] [US10] Write component test for AboutDialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/about_dialog_test.exs` — test renders "RetroHexChat" name, test renders version number, test renders ASCII art or logo, test renders credits text, test OK button present.

### Implementation

- [x] T078 [US10] Create AboutDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/about_dialog.ex` — retro dialog with: ASCII art logo in `<pre>` tag (pixelated "RHC" or hexagonal pattern), "RetroHexChat v1.0" title, "A retro IRC-style chat with retro aesthetics." description, "Built with Elixir, Phoenix LiveView, and retro design system." credits, OK button with `phx-click` close event. Styled like retro About boxes (icon + text layout).
- [x] T079 [US10] Replace inline about dialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — remove the existing generic `Dialog` usage for about and replace with `<AboutDialog visible={@show_about} on_close="close_dialog" />`.
- [x] T080 [US10] Add CSS for about dialog in `apps/retro_hex_chat_web/assets/css/chat.css` — `.about-dialog` layout, `.about-logo` monospace pre styling, `.about-credits` text styling. Add dark theme counterparts.
- [x] T081 [US10] Write E2E test for about dialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/about_e2e_test.exs` — test show_about renders AboutDialog with version and credits.

**Checkpoint**: US10 complete — polished About dialog with ASCII art and credits.

---

## Phase 13: User Story 11 — Help Menu Quick Access (Priority: P3)

**Goal**: Help menu items for "IRC Commands" and "Keyboard Shortcuts" opening help at those topics.

**Independent Test**: Click Help > IRC Commands and verify help dialog opens to commands section.

### Tests

- [x] T082 [P] [US11] Write LiveView tests for help quick access in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_help_access_test.exs` — test `open_help_at_topic` event with "keyboard-shortcuts" opens help dialog and selects that topic, test with commands overview topic ID works similarly.

### Implementation

- [x] T083 [US11] Create IRC Commands overview help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/commands.ex` — add a new topic `"commands-overview"` with title "IRC Commands Reference", category "Commands", listing all available slash commands with brief syntax and description. Include cross-references to individual command topics.
- [x] T084 [US11] Add `open_help_at_topic` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/help_events.ex` — handle `"open_help_at_topic"` with `%{"topic" => topic_id}`: open help dialog (set `show_help_dialog: true`), set `help_active_tab: "contents"`, set `help_selected_topic: HelpTopics.get_topic(topic_id)`.
- [x] T085 [US11] Add "IRC Commands" and "Keyboard Shortcuts" items to Help menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` — add two new `menu-dropdown-item` divs before "Help Topics": "IRC Commands" with `phx-click="open_help_at_topic" phx-value-topic="commands-overview"` and "Keyboard Shortcuts" with `phx-click="open_help_at_topic" phx-value-topic="keyboard-shortcuts"`. Add `data-testid` attributes.
- [x] T086 [US11] Write E2E tests for help menu quick access in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e/help_access_e2e_test.exs` — test IRC Commands menu item opens help at commands overview, test Keyboard Shortcuts menu item opens help at shortcuts topic.

**Checkpoint**: US11 complete — Help menu provides direct access to commands and shortcuts.

---

## Phase 14: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation for all new features, data-testid attributes, final validation.

- [x] T087 Add help topics for all new features in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — add topics: "feature-nick-alignment" (nick column alignment), "feature-copy" (right-click copy), "feature-paste-dialog" (multi-line paste), "feature-char-counter" (character counter), "feature-quit-message" (quit messages), "feature-away-reply" (away auto-reply), "feature-emoji" (emoji picker), "feature-timestamp-format" (timestamp configuration). Each with title, keywords, content with usage instructions, and "See Also" cross-references.
- [x] T088 Update keyboard shortcuts help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex` — add Ctrl+C (copy text), document emoji picker access.
- [x] T089 Add `data-testid` attributes to all new components and interactive elements — PasteConfirmDialog (`paste-confirm-dialog`, `paste-send-btn`, `paste-cancel-btn`), EmojiPicker (`emoji-picker`, `emoji-search`, `emoji-grid`), AboutDialog (`about-dialog`, `about-logo`), character counter (`char-counter`), copy menu (`copy-context-menu`), nick column grid (`chat-msg-grid`).
- [x] T090 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phases 3–13 (User Stories)**: All depend on Phase 2 completion
  - US1–US3 (P1) can run in parallel with each other
  - US4–US7 (P2) can run in parallel with each other
  - US8–US11 (P3) can run in parallel with each other
  - Priority order within tiers: P1 → P2 → P3
- **Phase 14 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Nick Column)**: Independent — CSS/template only
- **US2 (Double-Click)**: Independent — JS hooks + events
- **US3 (Right-Click Copy)**: Independent — JS hook only
- **US4 (Character Counter)**: Independent — JS hook only
- **US5 (Multi-Line Paste)**: Independent — JS hook + component + events
- **US6 (Quit Broadcast)**: Depends on Phase 2 (UserPreferences quit_message extension)
- **US7 (Away Auto-Reply)**: Independent — socket assigns only
- **US8 (Timestamp Format)**: Depends on Phase 2 (UserPreferences timestamp_format extension)
- **US9 (Emoji)**: Independent — new module + component
- **US10 (About Dialog)**: Independent — component replacement
- **US11 (Help Quick Access)**: Independent — event handler + menu items

### Parallel Opportunities

Within each phase, tasks marked `[P]` can run in parallel:
- Phase 2: T002 ∥ T003 (tests for different modules)
- Phase 3: T007 (tests) before T008-T010 (implementation)
- Phase 4: T012 ∥ T013 (tests for different actions)
- Phase 11: T065 ∥ T066 ∥ T067 (tests for different layers)

---

## Parallel Example: Phase 11 (Emoji Support)

```text
# Launch all tests in parallel:
T065: EmojiData unit tests (domain)
T066: EmojiPicker component tests (web)
T067: ChatLive emoji event tests (web)

# Then implementation sequentially:
T068: EmojiData module (domain, no web deps)
T069: EmojiPicker component (depends on T068 for data)
T070-T071: EmojiPickerHook JS + registration
T072: ChatLive event handlers
T073: Toolbar button
T074: Template integration
T075: CSS styling
T076: E2E tests (verify everything works together)
```

---

## Implementation Strategy

### MVP First (P1 Stories Only)

1. Complete Phase 1: Setup (verify baseline)
2. Complete Phase 2: Foundational (UserPreferences extension)
3. Complete Phase 3: US1 — Nick Column Alignment
4. **STOP and VALIDATE**: Messages visually aligned
5. Complete Phase 4: US2 — Double-Click Actions
6. Complete Phase 5: US3 — Right-Click Copy
7. **STOP and VALIDATE**: All P1 features working

### Incremental Delivery

1. P1 complete → Test all 3 stories → Checkpoint
2. Add P2 stories (US4–US7) → Test each independently → Checkpoint
3. Add P3 stories (US8–US11) → Test each independently → Checkpoint
4. Polish phase → Full CI validation → Done

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story (US1–US11)
- Constitution IV (TDD): Tests written FIRST, verified to fail, then implementation
- No new database migrations — JSONB column extension only
- 4 new JS hooks (CharCounter, Paste, ChatCopy, EmojiPicker) + 1 new JS hook (NicklistHook)
- Total: 90 tasks across 14 phases
