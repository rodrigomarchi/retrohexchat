# Tasks: Smart Input & Command Help

**Input**: Design documents from `/specs/024-smart-input-command-help/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Required by constitution Principle IV (TDD — non-negotiable). Tests are written before or alongside implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain**: `apps/retro_hex_chat/lib/retro_hex_chat/`
- **Web**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **JS Hooks**: `apps/retro_hex_chat_web/assets/js/hooks/`
- **CSS**: `apps/retro_hex_chat_web/assets/css/`
- **Domain Tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web Tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No project initialization needed — existing umbrella app. This phase creates shared domain structs and preference extensions that multiple user stories depend on.

- [x] T001 [P] Write unit tests for CommandSyntax, Parameter, and SubOption structs in `apps/retro_hex_chat/test/retro_hex_chat/commands/command_syntax_test.exs` — test struct creation, validation of parameter types, required/optional flags, sub-option flag format validation, and serialization to map for push_event payloads
- [x] T002 [P] Write unit tests for `command_help_level` preference in `apps/retro_hex_chat/test/retro_hex_chat/chat/user_preferences_test.exs` — test default value (:beginner), valid values (:beginner/:expert/:off), invalid value rejection, persistence round-trip (stringify/atomize), and inclusion in new()
- [x] T003 Create CommandSyntax, Parameter, and SubOption structs with @spec and typespecs in `apps/retro_hex_chat/lib/retro_hex_chat/commands/command_syntax.ex` — fields per data-model.md, include `to_client_payload/1` function to convert struct to map suitable for push_event
- [x] T004 Add `command_help_level` key to the display preferences category in `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` — add to `@valid_display_keys`, `default_display/0`, `set_display/3` validation, `stringify_display/1`, and `atomize_display/1`
- [x] T005 Add `syntax_definition/0` as an optional callback to the Handler behaviour in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex` — define @callback returning `CommandSyntax.t() | nil`, add `@optional_callbacks [syntax_definition: 0]`, include default implementation returning nil via `__using__` macro if one exists
- [x] T006 Add `get_syntax/1` and `all_syntax_definitions/0` functions to the Registry in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` — aggregate syntax definitions from all handlers at compile time (similar to existing `command_metadata/0` pattern), falling back to parsing help().syntax for handlers without syntax_definition/0

**Checkpoint**: Foundation ready — CommandSyntax structs exist, preference extended, Handler behaviour updated, Registry aggregates syntax data

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Convert `<input>` to `<textarea>` — this change affects ALL user stories and must be done first to avoid conflicting modifications.

**CRITICAL**: The textarea conversion is a prerequisite for US2 (placeholder on textarea), US3 (vertical expansion), and US4 (enhanced history on textarea). US1 (tooltip) also benefits from the textarea being in place.

- [x] T007 Write LiveView tests for textarea rendering and Enter/Shift+Enter behavior in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/smart_input_test.exs` — test that textarea renders with correct attributes (id="chat-input", name="input", maxlength="1000"), form submits on Enter, and existing phx-hook="AutocompleteHook" is preserved
- [x] T008 Replace `<input type="text">` with `<textarea>` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — change element, add `rows="1"`, `resize: none` inline or via CSS class, keep all existing attributes (id, name, value, placeholder, autocomplete, autofocus, maxlength, phx-hook)
- [x] T009 Update `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js` to handle textarea Enter/Shift+Enter behavior — intercept Enter keydown to prevent default newline and programmatically submit the form, allow Shift+Enter to insert newline, ensure all existing autocomplete logic (trigger detection, arrow keys, Tab, formatting shortcuts) works with textarea
- [x] T010 Add textarea-specific CSS in `apps/retro_hex_chat_web/assets/css/chat.css` — style `.chat-input-area textarea` to match existing input appearance (same font, padding, flex: 1, border), set `resize: none`, `overflow-y: hidden` (will be changed to auto in US3), single-line height by default, ensure retro design system compatibility
- [x] T011 Verify existing hooks work with textarea — manually confirm `char_counter_hook.js`, `paste_hook.js`, and `format_toolbar_hook.js` still function correctly (they use `.value`, `selectionStart`, `selectionEnd` which are identical on textarea). Fix any issues found.

**Checkpoint**: Textarea conversion complete — all existing functionality preserved, Enter sends, Shift+Enter creates newline

---

## Phase 3: User Story 1 — Command Syntax Tooltip (Priority: P1) MVP

**Goal**: When a user types or selects a recognized command, an inline syntax tooltip appears above the input showing parameter syntax with live highlighting of the next expected parameter.

**Independent Test**: Type `/mode ` and verify tooltip appears with syntax. Type arguments and verify highlighting updates. Press Escape to dismiss. Change detail level in settings.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US1] Write unit tests for syntax_definition/0 implementations in `apps/retro_hex_chat/test/retro_hex_chat/commands/command_syntax_test.exs` — test that mode, kick, join, msg, ban handlers return valid CommandSyntax structs with correct parameters, types, and sub-options (for mode)
- [x] T013 [P] [US1] Write LiveView tests for tooltip events in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/syntax_tooltip_test.exs` — test `syntax_tooltip_query` event returns tooltip data via push_event, `syntax_tooltip_dismiss` hides tooltip, tooltip not shown for unknown commands, tooltip not shown when autocomplete is open, detail level filtering (beginner/expert/off)

### Implementation for User Story 1

- [x] T014 [P] [US1] Implement `syntax_definition/0` in channel command handlers — add to `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/mode.ex` (with sub_options for +o/+v/+b/+i/+m/+t flags), `kick.ex`, `ban.ex`, `topic.ex`, `invite.ex`
- [x] T015 [P] [US1] Implement `syntax_definition/0` in user/basics command handlers — add to `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/msg.ex`, `join.ex`, `part.ex`, `nick.ex`, `quit.ex`, `query.ex`, `notice.ex`, `whois.ex`
- [x] T016 [P] [US1] Implement `syntax_definition/0` in remaining handlers — add to all remaining handlers in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/` (timer, clear, away, ignore, unignore, ctcp, action, list, names, who, identify, register, etc.)
- [x] T017 [US1] Create syntax tooltip function component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/syntax_tooltip.ex` — render tooltip panel with retro design system sunken border styling, syntax line with parameter highlighting (bold for current param), sub-options list, context message, and detail level variants (beginner: full, expert: syntax only)
- [x] T018 [US1] Add tooltip event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex` — handle `syntax_tooltip_query` (look up command in Registry, compute current_param_index from args, build context_message, push_event "syntax_tooltip_data"), handle `syntax_tooltip_dismiss` (push_event "syntax_tooltip_hide")
- [x] T019 [US1] Add tooltip assigns and rendering in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` and `chat_live.html.heex` — add `syntax_tooltip` assign (map or nil), render `<SyntaxTooltip>` component above input area (conditionally, when tooltip data present), coordinate with `show_autocomplete` assign
- [x] T020 [US1] Extend autocomplete_hook.js for tooltip triggers in `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js` — detect when input matches `/<command> ` pattern (command followed by space), push `syntax_tooltip_query` event with command name and current args, handle `syntax_tooltip_data` and `syntax_tooltip_hide` events to show/hide tooltip DOM, dismiss tooltip on Escape, suppress tooltip when `this.dropdownVisible` is true
- [x] T021 [US1] Add tooltip CSS styling in `apps/retro_hex_chat_web/assets/css/chat.css` — style `.syntax-tooltip` container (positioned above input, retro sunken panel, z-index below autocomplete dropdown), `.syntax-param` normal and `.syntax-param-active` bold highlighting, `.syntax-suboptions` list, `.syntax-context` message line
- [x] T022 [US1] Add command help level setting to Options dialog Display panel in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` — add radio buttons or select for Beginner/Expert/Off, wire to `update_command_help_level` event
- [x] T023 [US1] Handle `update_command_help_level` event in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex` — update display preferences with new command_help_level value, push updated preference to client

**Checkpoint**: Command syntax tooltip fully functional — type any command, see syntax with highlighting, dismiss with Escape, configure detail level in Settings

---

## Phase 4: User Story 2 — Contextual Input Placeholder (Priority: P2)

**Goal**: The input placeholder text dynamically reflects the active context — channel name, PM recipient, or Status window.

**Independent Test**: Switch between a channel, a PM, and the Status window. Verify placeholder changes immediately and accurately each time.

### Tests for User Story 2

- [x] T024 [US2] Write LiveView tests for dynamic placeholder in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/smart_input_test.exs` — test placeholder shows "Mensagem para #channel — / para comandos" in channel, "Mensagem para NickName — / para comandos" in PM, "Digite um comando — / para lista" in Status, placeholder updates on channel switch event

### Implementation for User Story 2

- [x] T025 [US2] Add `input_placeholder/1` helper function in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — compute placeholder string from socket assigns (check `show_status_tab`, `session.active_pm`, `session.active_channel` in priority order), return appropriate Portuguese text
- [x] T026 [US2] Update textarea placeholder attribute in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — replace static `"Type a message or /command..."` with dynamic `{input_placeholder(assigns)}` call, ensure placeholder updates on every relevant assign change (channel switch, PM switch, status tab toggle)

**Checkpoint**: Placeholder text dynamically reflects current context — channels, PMs, and Status window

---

## Phase 5: User Story 3 — Input Vertical Expansion (Priority: P3)

**Goal**: The textarea grows vertically as the user types multi-line content, up to 5 lines, then shows a scrollbar. The chat messages area compresses above.

**Independent Test**: Type or paste multi-line text. Verify input grows up to 5 lines, scrollbar appears for 6+ lines, chat area compresses, input shrinks back when text deleted.

### Tests for User Story 3

- [x] T027 [US3] Write LiveView tests for textarea expansion in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/smart_input_test.exs` — test that textarea renders with phx-hook="InputResizeHook" on the input area wrapper, test that textarea has correct initial rows="1" attribute

### Implementation for User Story 3

- [x] T028 [US3] Create InputResizeHook in `apps/retro_hex_chat_web/assets/js/hooks/input_resize_hook.js` — on mount, find textarea element, listen for `input` events, calculate scrollHeight, set textarea height dynamically up to max 5 lines (compute line height from CSS), toggle `overflow-y: auto` vs `hidden` based on whether content exceeds 5 lines, reset height on `set_input` event from server
- [x] T029 [US3] Register InputResizeHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add to Hooks object
- [x] T030 [US3] Add `phx-hook="InputResizeHook"` to the chat-input-area wrapper div in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — attach hook to the container div that wraps the textarea (note: CharCounterHook is already on this div, so either combine hooks or restructure with a nested div for the resize hook)
- [x] T031 [US3] Update CSS for textarea expansion in `apps/retro_hex_chat_web/assets/css/chat.css` — set textarea `min-height` to single line, `max-height` to 5 lines (calculate from line-height and padding), `transition: height 0.1s ease` for smooth growth, ensure `.chat-area` flex layout naturally compresses `.chat-messages` when input area grows (flex: 1 on messages + flex-shrink: 0 on input area already handles this)

**Checkpoint**: Textarea expands up to 5 lines, shows scrollbar beyond, chat area compresses proportionally, shrinks back on delete

---

## Phase 6: User Story 4 — Enhanced History Navigation (Priority: P4)

**Goal**: Ctrl+Up/Down navigates history while preserving draft text. Ctrl+R provides reverse search. History persists across page reloads in localStorage (100 entries, sensitive commands filtered).

**Independent Test**: Type partial text, press Ctrl+Up (draft saved, history shown), Ctrl+Down back to draft. Use Ctrl+R to search. Reload page — history persists. Send `/identify password` — verify it's not in localStorage.

### Tests for User Story 4

- [x] T032 [P] [US4] Write LiveView tests for enhanced history events in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/enhanced_history_test.exs` — test that existing Up/Down arrow history_navigate behavior is preserved, test that the history search component renders when triggered
- [x] T033 [P] [US4] Write unit tests for sensitive command filtering logic — if extracted to a shared module, test in `apps/retro_hex_chat/test/retro_hex_chat/commands/command_syntax_test.exs`, otherwise document expected JS behavior: `/identify`, `/nickserv`, `/ns` prefixes are filtered from persistence

### Implementation for User Story 4

- [x] T034 [US4] Create InputHistoryHook in `apps/retro_hex_chat_web/assets/js/hooks/input_history_hook.js` — implement localStorage-backed history buffer (key: `retro_hex_chat_history`, max 100 entries), load on mount, save on message send, sensitive command filter (static prefix list: `/identify`, `/nickserv`, `/ns`), graceful localStorage full handling (drop oldest via try/catch)
- [x] T035 [US4] Add Ctrl+Up/Down draft-preserving navigation to InputHistoryHook in `apps/retro_hex_chat_web/assets/js/hooks/input_history_hook.js` — on Ctrl+Up: save current input as draft (text + cursor position) if not already browsing, show previous history entry; on Ctrl+Down: show next entry or restore draft; on user typing while browsing: exit browsing mode, discard draft; on message send: discard draft, reset index
- [x] T036 [US4] Add Ctrl+R reverse search to InputHistoryHook in `apps/retro_hex_chat_web/assets/js/hooks/input_history_hook.js` — on Ctrl+R: show inline search UI (small bar below or above input with "Search history:" label and text field), on typing: filter history entries by substring match, show most recent match in input field, on Enter: accept match and close search, on Escape: cancel search and restore original input, show "No match" when no results
- [x] T037 [US4] Create HistorySearch component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/history_search.ex` — render inline search bar with retro styling (sunken field, label "Pesquisar histórico:"), status text area for "No match" indicator, styled to appear above the input area without overlapping tooltip
- [x] T038 [US4] Register InputHistoryHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add to Hooks object
- [x] T039 [US4] Attach InputHistoryHook to input area in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — add a wrapper div with `phx-hook="InputHistoryHook"` around or near the textarea (coordinate with InputResizeHook and CharCounterHook placement), render HistorySearch component conditionally
- [x] T040 [US4] Integrate Ctrl+Up/Down/R keyboard detection with existing AutocompleteHook in `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js` — ensure Ctrl+Up/Down are intercepted before regular Up/Down history_navigate, ensure Ctrl+R is intercepted before browser default (find), coordinate with existing keyboard shortcut system (custom bindings take precedence)
- [x] T041 [US4] Add CSS for history search bar in `apps/retro_hex_chat_web/assets/css/chat.css` — style `.history-search-bar` (positioned above input, compact height, retro sunken panel), `.history-search-input` text field, `.history-no-match` indicator styling

**Checkpoint**: Enhanced history fully functional — Ctrl+Up/Down with draft, Ctrl+R search, localStorage persistence, sensitive filtering

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, final integration, and validation across all stories

- [x] T042 [P] Add "Command Syntax Tooltip" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — describe tooltip behavior, detail levels (Beginner/Expert/Off), Escape to dismiss, how it coordinates with autocomplete, link to Settings, add keywords for search
- [x] T043 [P] Add "Smart Input" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — describe contextual placeholder text, multi-line expansion (up to 5 lines), Enter to send / Shift+Enter for newline, add keywords for search
- [x] T044 [P] Add "Enhanced History" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — describe Ctrl+Up/Down with draft preservation, Ctrl+R reverse search, localStorage persistence (100 entries), sensitive command filtering, add keywords for search
- [x] T045 Update "Keyboard Shortcuts" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex` — add Ctrl+Up/Down (history with draft), Ctrl+R (reverse search), Shift+Enter (newline in input), Escape (dismiss tooltip), update existing shortcuts if any behavior changed
- [x] T046 Update "See Also" cross-references in related existing help topics — link Autocomplete topic to Command Syntax Tooltip, link Commands topic to Syntax Tooltip, link Features overview to new topics
- [x] T047 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — T001-T002 tests in parallel, then T003-T006 implementation
- **Phase 2 (Foundational)**: Depends on Phase 1 (T003 CommandSyntax struct needed for T005 handler callback type) — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 1 (syntax structs, preference) + Phase 2 (textarea in place)
- **Phase 4 (US2)**: Depends on Phase 2 (textarea placeholder attribute)
- **Phase 5 (US3)**: Depends on Phase 2 (textarea element exists for resize)
- **Phase 6 (US4)**: Depends on Phase 2 (textarea for Ctrl+Up/Down/R interception)
- **Phase 7 (Polish)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (Syntax Tooltip)**: Independent after Phase 2. Core MVP.
- **US2 (Placeholder)**: Independent after Phase 2. No dependency on US1.
- **US3 (Expansion)**: Independent after Phase 2. No dependency on US1/US2.
- **US4 (History)**: Independent after Phase 2. No dependency on US1/US2/US3.

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Constitution IV)
- Domain changes before web layer
- Server-side components before client-side hooks
- Elixir components before JavaScript hooks
- CSS styling after component structure is in place

### Parallel Opportunities

**Phase 1**: T001 and T002 (tests) in parallel → then T003, T004, T005, T006 (implementation, T003-T004 in parallel)

**Phase 2**: Sequential (all touch the same input area)

**Phase 3 (US1)**: T012 and T013 (tests) in parallel → T014, T015, T016 (handler syntax_definition) all in parallel → T017, T018, T019 sequentially → T020, T021 in parallel → T022, T023 in parallel

**Phase 4-6**: US2, US3, US4 can be done in parallel with each other (different files), or sequentially after US1

**Phase 7**: T042, T043, T044, T045 all in parallel (different help topic files)

---

## Parallel Example: Phase 1

```bash
# Launch tests in parallel:
Task: T001 "Unit tests for CommandSyntax structs"
Task: T002 "Unit tests for command_help_level preference"

# After tests pass (they should fail), launch implementation in parallel:
Task: T003 "Create CommandSyntax/Parameter/SubOption structs"
Task: T004 "Add command_help_level to display preferences"

# Then sequentially (depends on T003):
Task: T005 "Add syntax_definition/0 callback to Handler"
Task: T006 "Add get_syntax/all_syntax_definitions to Registry"
```

## Parallel Example: Phase 3 (US1)

```bash
# Launch handler implementations in parallel (different files):
Task: T014 "syntax_definition/0 in channel handlers"
Task: T015 "syntax_definition/0 in user/basics handlers"
Task: T016 "syntax_definition/0 in remaining handlers"

# After handlers done, launch component + event handler:
Task: T017 "Syntax tooltip component"
Task: T018 "Tooltip event handlers"
# Then template integration:
Task: T019 "Add tooltip to template"

# Finally, client-side in parallel:
Task: T020 "Extend autocomplete_hook for tooltip"
Task: T021 "Tooltip CSS styling"
Task: T022 "Options dialog help level setting"
Task: T023 "Handle update_command_help_level event"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (structs, preferences, callbacks)
2. Complete Phase 2: Foundational (textarea conversion)
3. Complete Phase 3: User Story 1 (syntax tooltip)
4. **STOP and VALIDATE**: Test tooltip independently — type commands, verify syntax appears, parameter highlighting works, Escape dismisses, detail levels work
5. Run CI validation pipeline (T047)

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation ready
2. Add US1 (tooltip) → Test independently → **MVP complete**
3. Add US2 (placeholder) → Test independently → Contextual polish added
4. Add US3 (expansion) → Test independently → Multi-line input enabled
5. Add US4 (history) → Test independently → Power-user features complete
6. Phase 7 (polish) → Help docs, final validation
7. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable after Phase 2
- Constitution IV mandates TDD — write tests first, verify they fail
- Constitution XI mandates help topics for all user-facing features (Phase 7)
- The textarea conversion (Phase 2) is the highest-risk change — verify all existing hooks work before proceeding
- Sensitive command list for history filtering: `/identify`, `/nickserv`, `/ns` (static, not regex)
- No database migrations needed — preferences use JSON column
