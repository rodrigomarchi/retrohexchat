# Tasks: Autocomplete System

**Input**: Design documents from `/specs/023-autocomplete-system/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — TDD is non-negotiable per Constitution Principle IV.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the core domain module and behaviour extension that all stories depend on.

- [x] T001 Add `category/0` optional callback to Handler behaviour with default implementation in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex`. Add `@callback category() :: :basics | :channel | :user | :config | :advanced` with `@optional_callbacks [category: 0]` and a default fallback in Registry for handlers that don't implement it yet (default to `:basics`).

- [x] T002 Create `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex` module with `@moduledoc`, type definitions for `command_result()`, `nick_result()`, `channel_result()`, and stub `@spec` annotations for: `fuzzy_match/2`, `search_commands/2`, `search_nicks/3`, `search_channels/2`, `argument_context/1`. Implement only `fuzzy_match/2` in this task — stubs for the rest return empty lists.

- [x] T003 [P] Write unit tests for `fuzzy_match/2` in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Test cases: exact prefix match scores highest, word-boundary subsequence scores medium, general subsequence scores lowest, non-matching returns `:no_match`, empty query matches everything, case-insensitive matching, matched character indices are correct. Tag `@tag :unit`.

- [x] T004 Implement `fuzzy_match/2` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex` to pass all T003 tests. Algorithm: (1) exact prefix → score 1000 + length_bonus, (2) word-boundary subsequence → score 500, (3) general subsequence → score 100, (4) no match → `:no_match`. Return `{:match, score, matched_indices}` or `:no_match`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared infrastructure that MUST be complete before ANY user story can proceed.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Add `category/0` implementation to ALL handler modules (42+ files) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/`. Use the category mapping from research.md: Básicos (help, clear, quit, away, bio, nick, me), Canal (join, part, leave, list, topic, mode, kick, ban, invite, knock), Usuário (msg, query, notice, notice_routing, whois, whowas, ctcp, wallops, ignore, unignore), Configuração (alias, autojoin, autorespond, notify, perform, timer, popups, umode), Avançado (announce, cs, ns, motd, setmotd, clearmotd, setwelcome, clearwelcome). Each handler adds `@impl true` and `def category, do: :category_atom`.

- [x] T006 [P] Add `command_metadata/0` and `commands_by_category/0` to `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`. `command_metadata/0` returns `[%{name: String.t(), description: String.t(), category: String.t()}]` by calling `handler.help()` and `handler.category()` for each registered command. `commands_by_category/0` returns commands grouped by category label in display order (Recentes placeholder, Básicos, Canal, Usuário, Configuração, Avançado). Add `@spec` annotations and compile-time memoization via module attribute.

- [x] T007 [P] Write tests for `command_metadata/0` and `commands_by_category/0` in `apps/retro_hex_chat/test/retro_hex_chat/commands/registry_test.exs`. Test: all 45 commands present, each has name+description+category, categories are correctly grouped, category order is correct. Tag `@tag :unit`.

- [x] T008 Rename `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/command_palette.ex` → `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/autocomplete_dropdown.ex`. Rename the module to `RetroHexChatWeb.Components.AutocompleteDropdown`. Create the base `autocomplete_dropdown/1` component with attributes: `visible` (boolean), `mode` (atom: `:command`/`:nick`/`:channel`), `results` (list), `selected` (integer, 0-based index). Render a retro design system `window` div with `title-bar` showing mode-appropriate title, and `window-body` with `tree-view` `ul`. Support `:command` mode rendering initially (others added in later stories). Update all references in ChatLive template (`chat_live.html.heex`) to use new component name.

- [x] T009 Rename `apps/retro_hex_chat_web/assets/js/hooks/command_palette_hook.js` → `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. Rename the hook export to `AutocompleteHook`. Preserve ALL existing functionality (PM typing, history navigation, IRC formatting shortcuts). Refactor the trigger detection: replace hardcoded `/` detection with a `detectTrigger()` function that scans backward from cursor position. For now, only detect `/` at position 0 (same as before). Push new event names: `autocomplete_query` (replaces `open_command_palette` + `filter_command_palette`), `autocomplete_close` (replaces `close_command_palette`), `autocomplete_select` (replaces `select_command`). Add `autocomplete_navigate` for ↑/↓ when dropdown is visible. Update hook registration in `apps/retro_hex_chat_web/assets/js/app.js`.

- [x] T010 Update ChatLive assigns in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` `assign_defaults/2`. Replace `command_palette_visible: false` and `command_palette_filter: ""` with: `autocomplete_visible: false`, `autocomplete_mode: nil`, `autocomplete_results: []`, `autocomplete_filter: ""`, `autocomplete_selected: 0`, `tab_cycle_matches: []`, `tab_cycle_index: 0`, `tab_cycle_partial: nil`. Update the HEEx template to render `<AutocompleteDropdown.autocomplete_dropdown>` with new assign names. Update `phx-hook` from `"CommandPaletteHook"` to `"AutocompleteHook"`.

- [x] T011 Update event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`. Replace `open_command_palette`, `close_command_palette`, `filter_command_palette`, `select_command` handlers with: `autocomplete_query` (dispatches to appropriate search function based on `type` param), `autocomplete_close` (resets all autocomplete assigns), `autocomplete_select` (inserts selection into input based on type), `autocomplete_navigate` (increments/decrements `autocomplete_selected` with wrapping). For now, `autocomplete_query` with `type: "command"` calls `Autocomplete.search_commands/2`.

- [x] T012 Update CSS styles in `apps/retro_hex_chat_web/assets/css/components.css`. Rename `.command-palette-item` to `.autocomplete-item`. Add styles for: `.autocomplete-item.selected` (navy background, white text — keyboard selection), `.autocomplete-category-header` (bold, non-selectable, slightly smaller font), `.autocomplete-no-results` (italic, dimmed text), `.autocomplete-match-highlight` (bold or underline for fuzzy-matched characters). Ensure max-height 250px with `overflow-y: auto` on the list container.

- [x] T013 [P] Rename `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/command_palette_test.exs` → `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/autocomplete_dropdown_test.exs`. Update module name, imports. Rewrite existing 3 tests to work with new component API (visible, mode, results, selected). Keep tests minimal — just verify rendering with `:command` mode.

**Checkpoint**: Foundation ready — autocomplete infrastructure replaces old command palette. App compiles and existing functionality (/ command palette) still works with new event flow.

---

## Phase 3: User Story 1 - Enhanced Command Autocomplete (Priority: P1) 🎯 MVP

**Goal**: Fuzzy search, categories, and recent commands in the command palette.

**Independent Test**: Type `/` → see categorized commands. Type `/jo` → fuzzy match shows `/join` + `/autojoin`. Select → input fills. Recent commands appear at top.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T014 [P] [US1] Write unit tests for `search_commands/2` in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Test: empty query returns all commands grouped by category, fuzzy query "jo" returns join+autojoin with scores, recent commands marked with `recent?: true`, results sorted by score descending then alphabetically, commands have correct category labels. Tag `@tag :unit`.

- [x] T015 [P] [US1] Write component tests for category rendering in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/autocomplete_dropdown_test.exs`. Test: `:command` mode renders category headers (Básicos, Canal, etc.), selected item has `.selected` class, fuzzy match characters are highlighted, "Recentes" section appears when recent commands present, empty "Recentes" section is hidden. Tag `@tag :liveview`.

### Implementation for User Story 1

- [x] T016 [US1] Implement `search_commands/2` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex`. Takes `(partial, recent_commands_list)`. Uses `command_metadata/0` from Registry, applies `fuzzy_match/2` to each command name, marks recent commands, sorts by: recents first (preserving recency order), then by score descending, then alphabetical. Returns `[command_result()]` capped at 20 results.

- [x] T017 [US1] Enhance `:command` mode rendering in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/autocomplete_dropdown.ex`. Render commands grouped by category with `<li class="autocomplete-category-header">` section headers. Each command item shows `/{name}` with description text. Highlight fuzzy-matched characters using `<strong>` tags based on `matched_chars` indices. Show "Recentes" category first (only if non-empty). Apply `.selected` CSS class to item at `@selected` index. Emit `phx-click="autocomplete_select"` with `phx-value-type="command"` and `phx-value-value={name}` on each item.

- [x] T018 [US1] Update `autocomplete_query` handler for command type in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`. When `type: "command"`, call `Autocomplete.search_commands(partial, recent_commands)` where `recent_commands` comes from a new socket assign `recent_commands: []` (populated via `push_event` from hook on mount). Update assigns: `autocomplete_visible: true`, `autocomplete_mode: :command`, `autocomplete_results: results`, `autocomplete_filter: partial`, `autocomplete_selected: 0`.

- [x] T019 [US1] Implement recent commands localStorage logic in `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. On mount: read `retro_hex_chat_recent_commands` from localStorage, push `recent_commands_loaded` event to server with the list. On command execution (Enter on `/command` with args): save command name to localStorage (deduplicate, cap at 5, most recent first). Add `handleEvent("request_recent_commands", ...)` listener that pushes current recents to server.

- [x] T020 [US1] Add `recent_commands_loaded` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`. Store the received list in `socket.assigns.recent_commands`. This assign is used by `search_commands/2` when processing `autocomplete_query` events.

- [x] T021 [US1] Write LiveView integration test for command autocomplete flow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_test.exs`. Test full flow: connect user → type `/` → verify dropdown visible with categorized commands → type `/jo` → verify fuzzy-filtered results → simulate autocomplete_select → verify input updated to `/join ` and dropdown closed. Tag `@tag :liveview`.

**Checkpoint**: User Story 1 complete — command palette has fuzzy search, categories, recent commands, keyboard navigation.

---

## Phase 4: User Story 2 - Nick Autocomplete (Priority: P2)

**Goal**: `@` trigger shows nick dropdown with status/color. Tab cycling completes nicks IRC-style.

**Independent Test**: In a channel, type `@ma` → see matching nicks. Press Tab on bare `Mar` → completes to `Mario: `. Tab again → cycles to next match.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T022 [P] [US2] Write unit tests for `search_nicks/3` in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Test: fuzzy match on nicknames, online users before away users, own nick deprioritized to end of list, empty query returns all channel users (sorted), results capped at 20, status field correctly set from Presence data. Tag `@tag :unit`.

- [x] T023 [P] [US2] Write unit tests for enhanced Tab cycling in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Add a `tab_complete_matches/3` function test: given partial "Mar" and users list, returns alphabetically sorted matching nicks. Test: single match returns one-element list, multiple matches sorted alphabetically, no matches returns empty list, case-insensitive prefix matching, own nick excluded from first position. Tag `@tag :unit`.

### Implementation for User Story 2

- [x] T024 [US2] Implement `search_nicks/3` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex`. Takes `(partial, channel_users, own_nickname)`. Applies `fuzzy_match/2` to each user's nickname. Maps each result to `nick_result()` with status (`:online`/`:away`), color (from user metadata if available), and `self?` flag. Sorts: online before away, then by score, then alphabetical. Deprioritizes own nick (moves to end). Caps at 20 results.

- [x] T025 [US2] Add `@` word-boundary trigger detection to `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. In `detectTrigger()`, after checking for `/` at position 0, scan backward from cursor to find `@` preceded by whitespace or at position 0. If found and 1+ characters follow, push `autocomplete_query` with `{type: "nick", partial: textAfterAt}`. If dropdown is visible with mode "nick" and user deletes past `@`, push `autocomplete_close`.

- [x] T026 [US2] Add `:nick` mode rendering to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/autocomplete_dropdown.ex`. Each nick item shows: nick color swatch (small colored circle or background), nickname text with fuzzy highlight, status indicator (green dot = online, yellow dot = away), away message tooltip if present. Title bar shows "Nicknames". Apply `.selected` class to `@selected` index. Emit `phx-click="autocomplete_select"` with `phx-value-type="nick"`.

- [x] T027 [US2] Add nick autocomplete event handling in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`. Handle `autocomplete_query` with `type: "nick"`: call `Autocomplete.search_nicks(partial, channel_users, session.nickname)`. Handle `autocomplete_select` with `type: "nick"`: replace the `@partial` text in input with `@NickName `. If in Status window (no active channel), ignore nick queries.

- [x] T028 [US2] Implement `tab_complete_matches/3` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex`. Takes `(partial, channel_users, own_nickname)`. Returns alphabetically sorted list of matching nicknames (prefix match, case-insensitive). Own nick moved to end of list. Used by the enhanced `tab_complete` event handler.

- [x] T029 [US2] Enhance `tab_complete` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`. Replace single-match logic with: call `Autocomplete.tab_complete_matches/3`, if matches found push `tab_matches` event to hook with `%{matches: matches, is_start: is_start}`. Remove the old inline `Enum.filter` + single-match logic.

- [x] T030 [US2] Add Tab cycling state management to `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. Handle `tab_matches` event: store `{original, matches, index, isStart}` in hook state. Insert first match with appropriate suffix (`: ` if `isStart`, ` ` otherwise). On subsequent Tab presses (while cycling state exists): increment index (wrap at end), replace current completion with next match. On any non-Tab keypress: clear cycling state. Ensure Tab is only intercepted when NOT in an autocomplete dropdown — if dropdown is visible, Tab selects from dropdown instead.

- [x] T031 [US2] Write LiveView integration test for nick autocomplete in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_test.exs`. Test: connect two users to same channel → user1 types `@` + partial of user2's nick → verify dropdown shows user2 → verify own nick deprioritized. Test Status window: verify `@` trigger is ignored. Tag `@tag :liveview`.

**Checkpoint**: User Story 2 complete — nick autocomplete works via `@` trigger and Tab cycling.

---

## Phase 5: User Story 3 - Context-Aware Argument Completion (Priority: P3)

**Goal**: After selecting a command, the system suggests appropriate arguments (nicks for `/msg`, channels for `/join`).

**Independent Test**: Type `/join #` → see channel list. Type `/msg m` → see nick suggestions. Type `/kick n` → see current channel nicks only.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T032 [P] [US3] Write unit tests for `argument_context/1` in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Test: `argument_context("msg")` returns `{:nick, :all_channels}`, `argument_context("join")` returns `{:channel, :all}`, `argument_context("kick")` returns `{:nick, :current_channel}`, `argument_context("help")` returns `nil`, all nick-expecting commands (msg, query, whois, whowas, notice, ctcp, kick, ban) return appropriate nick context, all channel-expecting commands (join, part, topic, mode) return channel context. Tag `@tag :unit`.

### Implementation for User Story 3

- [x] T033 [US3] Implement `argument_context/1` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex`. Takes a command name string. Returns `{:nick, :all_channels}` for msg/query/whois/whowas/notice/ctcp, `{:nick, :current_channel}` for kick/ban, `{:channel, :all}` for join/part/topic/mode/invite, or `nil` for commands that don't take nick/channel arguments.

- [x] T034 [US3] Add command argument context detection to `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. In `detectTrigger()`, after a command has been completed (input matches `/command arg_partial`): extract command name and argument text. Push `autocomplete_query` with `{type: "arg_nick" | "arg_channel", partial: argText, command: commandName}`. The hook detects this state when input starts with `/`, contains a space, and the first word (command) is known to have arguments.

- [x] T035 [US3] Handle `arg_nick` and `arg_channel` types in `autocomplete_query` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`. For `arg_nick` with `:current_channel` scope: call `search_nicks(partial, channel_users, nickname)`. For `arg_nick` with `:all_channels` scope: aggregate users from all joined channels via Presence, deduplicate, then call `search_nicks(partial, all_users, nickname)`. For `arg_channel`: call `search_channels(partial, user_channels)` (requires T038 from US4). Handle `autocomplete_select` for arg types: insert the selected value after the command + space in the input.

- [x] T036 [US3] Write LiveView integration test for argument completion in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_test.exs`. Test: user types `/join ` → verify mode switches to channel suggestions (if search_channels implemented). User types `/msg ` + partial nick → verify nick suggestions from all channels. User types `/kick ` + partial → verify only current channel nicks shown. Tag `@tag :liveview`.

**Checkpoint**: User Story 3 complete — argument completion works for nick-expecting and channel-expecting commands.

---

## Phase 6: User Story 4 - Channel Autocomplete (Priority: P4)

**Goal**: `#` trigger shows matching channels with user counts and joined status. Secret channels hidden from non-members.

**Independent Test**: Type `#de` → see matching channels with counts and joined badges. Secret channels invisible to non-members.

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T037 [P] [US4] Write unit tests for `search_channels/2` in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Test: fuzzy match on channel names (without `#` prefix), joined channels sorted first, secret channels excluded for non-members, secret channels included for members, user_count populated, results capped at 20. Tag `@tag :unit`. NOTE: This requires mocking channel state — use a test helper that provides channel data as a list of maps rather than querying live Registry.

- [x] T038 [P] [US4] Write unit tests for `list_visible_channels/1` in `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`. Test: returns `[%{name, user_count, topic, secret?}]` for all active channels, secret channels excluded for non-members, private channels shown as "Prv" for non-members, member always sees their channels. Tag `@tag :integration` (requires Channel GenServer).

### Implementation for User Story 4

- [x] T039 [US4] Extract `list_visible_channels/1` from `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/channel_list_live.ex` into `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex` (or a shared `Channels` context function). Takes `user_channels` (list of channel names the user has joined). Queries the Channel Registry, calls `Server.get_state/1` for each, applies visibility rules (secret/private filtering). Returns `[%{name: String.t(), user_count: integer(), topic: String.t() | nil}]`. Refactor `ChannelListLive` to call this shared function instead of its private `list_active_channels/1`.

- [x] T040 [US4] Implement `search_channels/2` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/autocomplete.ex`. Takes `(partial, user_channels)`. Calls `list_visible_channels(user_channels)`, applies `fuzzy_match/2` to channel names (strip `#` prefix for matching). Maps to `channel_result()` with `joined?` flag. Sorts: joined channels first, then by score, then alphabetical. Caps at 20 results.

- [x] T041 [US4] Add `#` word-boundary trigger detection to `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. In `detectTrigger()`, scan backward from cursor for `#` preceded by whitespace or at position 0. If found and 1+ characters follow, push `autocomplete_query` with `{type: "channel", partial: textAfterHash}`. If dropdown visible with mode "channel" and user deletes past `#`, push `autocomplete_close`.

- [x] T042 [US4] Add `:channel` mode rendering to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/autocomplete_dropdown.ex`. Each channel item shows: `#channelname` with fuzzy highlight, user count badge (e.g., "(5 users)"), joined indicator (checkmark icon or `✓` before name for joined channels). Title bar shows "Channels". Apply `.selected` class. Emit `phx-click="autocomplete_select"` with `phx-value-type="channel"`.

- [x] T043 [US4] Handle channel autocomplete events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`. Handle `autocomplete_query` with `type: "channel"`: call `Autocomplete.search_channels(partial, session.channels)`. Handle `autocomplete_select` with `type: "channel"`: insert the full channel name (with `#` prefix) at the cursor position in input.

- [x] T044 [US4] Write LiveView integration test for channel autocomplete in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_test.exs`. Test: create channels → user types `#` + partial → verify dropdown shows matching channels with user counts → verify joined channels appear first. Test secret channel filtering: create secret channel → verify non-member doesn't see it. Tag `@tag :liveview`.

**Checkpoint**: User Story 4 complete — channel autocomplete works via `#` trigger with visibility rules.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, edge case handling, and final validation.

- [x] T045 [P] Add "Autocomplete" help topic to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex`. Topic ID: `"feature-autocomplete"`, category: `"Features"`. Content covers: command autocomplete (`/` trigger, fuzzy search, categories, recent commands), nick autocomplete (`@` trigger, Tab cycling, IRC-style colon completion), channel autocomplete (`#` trigger, joined-first sorting), keyboard shortcuts (Tab/Enter to select, ↑/↓ to navigate, Escape to dismiss). Include "See Also" links to `"keyboard-shortcuts"` and `"getting-started"` topics.

- [x] T046 [P] Update "Keyboard Shortcuts" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex`. Add entries for: `Tab` — autocomplete selection / nick cycling, `@` — nick autocomplete trigger, `#` — channel autocomplete trigger, `↑/↓` — navigate autocomplete dropdown. Add "See Also" link to `"feature-autocomplete"`.

- [x] T047 Add "No results" message rendering to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/autocomplete_dropdown.ex`. When `@results` is empty and `@visible` is true, render `<li class="autocomplete-no-results">No results</li>` instead of an empty list. Style with italic, dimmed text per T012 CSS.

- [x] T048 Add viewport boundary detection to `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js`. After the dropdown is rendered (using a `MutationObserver` or `updated()` lifecycle hook), check if the dropdown extends beyond the viewport. If so, adjust positioning (e.g., switch from `bottom: 100%` to `top: 100%`, or constrain width). This is a JS-only concern since positioning requires DOM measurement.

- [x] T049 [P] Write E2E test for full autocomplete workflow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_e2e_test.exs`. Test the complete user journey: user connects → types `/jo` → verifies fuzzy results → selects `/join` → types `#` → verifies channel suggestions → selects channel. Verify no messages sent during autocomplete. Tag `@tag :e2e`.

- [x] T050 Run full CI-equivalent validation pipeline: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `mix test --include e2e`, `mix dialyzer`. Fix any failures. Ensure all new public functions have `@spec`. Ensure no Credo nesting depth violations (max 2 — extract helpers if needed).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T001-T004) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 completion
- **US2 (Phase 4)**: Depends on Phase 2 completion. Can proceed in parallel with US1 but practically benefits from US1's component/event infrastructure.
- **US3 (Phase 5)**: Depends on Phase 2. Depends on US2 (T024 for `search_nicks`) and US4 (T040 for `search_channels`). Can partially start (T032-T033) before US2/US4 complete.
- **US4 (Phase 6)**: Depends on Phase 2 completion. Can proceed in parallel with US1/US2.
- **Polish (Phase 7)**: Depends on US1-US4 being complete

### User Story Dependencies

- **US1 (P1)**: Standalone after Phase 2 — no cross-story deps
- **US2 (P2)**: Standalone after Phase 2 — no cross-story deps
- **US3 (P3)**: Depends on US2 (`search_nicks`) and US4 (`search_channels`) for full functionality
- **US4 (P4)**: Standalone after Phase 2 — no cross-story deps

### Within Each User Story

- Tests written FIRST (TDD — Constitution Principle IV)
- Domain logic before web layer
- Components before event handlers
- Integration tests after implementation

### Parallel Opportunities

- T003 (fuzzy_match tests) can parallel with T001 (behaviour change)
- T006 + T007 (Registry enhancements) parallel with T008 + T009 (component/hook rename)
- T013 (test rename) parallel with T006-T012
- T014 + T015 (US1 tests) parallel with each other
- T022 + T023 (US2 tests) parallel with each other
- T032 (US3 tests) parallel with T037 + T038 (US4 tests)
- T045 + T046 (help topics) parallel with each other and T047-T048

---

## Parallel Example: Phase 2 (Foundational)

```text
# Group A: Domain layer (parallel)
T005: Add category() to all handlers
T006: Add command_metadata/0 to Registry
T007: Tests for Registry enhancements

# Group B: Web layer (parallel with Group A)
T008: Rename component → autocomplete_dropdown.ex
T009: Rename hook → autocomplete_hook.js
T013: Rename test file

# Sequential after A+B:
T010: Update ChatLive assigns (depends on T008, T009)
T011: Update event handlers (depends on T010)
T012: Update CSS
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T013)
3. Complete Phase 3: User Story 1 (T014-T021)
4. **STOP and VALIDATE**: Test command autocomplete independently
5. Deploy/demo — enhanced command palette with fuzzy search + categories + recents

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. US1 → Fuzzy command palette with categories (MVP!)
3. US2 → Nick autocomplete + Tab cycling
4. US3 → Argument completion (needs US2 + US4)
5. US4 → Channel autocomplete
6. Polish → Help docs, edge cases, CI validation
7. Each story adds value without breaking previous stories

### Recommended Execution Order

Since US3 depends on US2 and US4, the optimal order is:
**Phase 1 → Phase 2 → US1 → US2 + US4 (parallel) → US3 → Polish**

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- TDD is mandatory — all test tasks MUST be completed before their implementation counterparts
- Run `mix compile --warnings-as-errors` after each phase to catch issues early
- No new database migrations — all data from runtime state
- 42+ handler files need `category/0` added (T005) — consider batching with a script or doing 5-6 at a time
