# Tasks: Context Menus

**Input**: Design documents from `/specs/026-context-menus/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — Constitution Principle IV (TDD) is non-negotiable.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize socket assigns, CSS foundations, and shared JS utilities for all context menus.

- [x] T001 Add `chat_context_menu` default assign to `assign_defaults` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — initialize with `%{visible: false, type: nil, x: 0, y: 0, target_nick: nil, target_url: nil, target_channel: nil, target_message: nil, has_selection: false}`
- [x] T002 [P] Add `muted_channels` assign (MapSet) to `assign_defaults` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — load from `session.user_preferences.message_settings.muted_channels` on mount
- [x] T003 [P] Add muted_channels helpers to `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` — `get_muted_channels/1`, `set_muted_channels/2`, `toggle_mute_channel/2` with @spec annotations
- [x] T004 [P] Add CSS for context menu disabled state, focused state, and shortcut hint alignment in `apps/retro_hex_chat_web/assets/css/components.css` — `.context-menu li.disabled` (grayed out, no pointer), `.context-menu li.focused` (navy background like hover), `.context-menu .shortcut-hint` (float right, margin-left)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Data attributes on chat HTML, smart right-click detection in JS, context menu keyboard nav hook, and clipboard push_event handler. MUST complete before ANY user story.

**CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundational

- [x] T005 Write tests for `get_muted_channels/1`, `set_muted_channels/2`, `toggle_mute_channel/2` in `apps/retro_hex_chat/test/retro_hex_chat/chat/user_preferences_test.exs`
- [x] T006 [P] Write LiveView test verifying `data-nick` attribute appears on `.chat-nick` spans and `data-author`, `data-message-id` appear on `.chat-message` divs in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`

### Implementation for Foundational

- [x] T007 Add `data-nick` attribute to `.chat-nick` spans in message rendering in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — set to the author's nickname
- [x] T008 Add `data-author`, `data-message-id`, and `data-system-message` attributes to `.chat-message` wrapper divs in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T009 Add `data-url` attribute to `.chat-link` elements in URL linkification in `apps/retro_hex_chat/lib/retro_hex_chat/chat/url_detector.ex` — set to the href value
- [x] T010 Create context menu JS hook in `apps/retro_hex_chat_web/assets/js/hooks/context_menu_hook.js` — implement viewport repositioning (measure on mounted/updated, flip if overflow), keyboard navigation (ArrowUp/Down/Enter/Escape), and focus management with `.focused` class
- [x] T011 Register `ContextMenuHook` in `apps/retro_hex_chat_web/assets/js/hooks/index.js` (or equivalent hook registration file)
- [x] T012 Replace existing simple copy menu in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js` with smart right-click detection — inspect `e.target` ancestry for `.chat-nick[data-nick]` → nick, `.chat-link[data-url]` → url, `.chat-channel-link[data-channel]` → channel, `.chat-message` → message fallback. Respect priority order: nick > URL > channel > message. Preserve browser default context menu for input fields. Push `chat_context_menu` event with typed payload per contracts
- [x] T013 Add `clipboard_copy` and `open_url` push_event handlers in scroll_hook.js or a shared hook — `this.handleEvent("clipboard_copy", ({text}) => navigator.clipboard.writeText(text))` and `this.handleEvent("open_url", ({url}) => window.open(url, "_blank", "noopener,noreferrer"))`

**Checkpoint**: Foundation ready — data attributes on HTML, smart right-click detection, keyboard nav hook, clipboard handlers all in place.

---

## Phase 3: User Story 1 — Nick Context Menu in Chat Area (Priority: P1) MVP

**Goal**: Right-clicking a nickname prefix in a chat message shows a context menu with PM, Whois, Copy Nick, Ignore, Address Book, Nick Color, and operator actions (Kick, Ban, Voice, Op). Keyboard shortcuts displayed. Disabled states for unavailable actions.

**Independent Test**: Right-click any `<Alice>` prefix in chat → menu appears with correct items, shortcuts, disabled states. Op actions hidden for non-ops. Self-targeting actions grayed out.

### Tests for User Story 1

- [x] T014 [P] [US1] Write LiveView test: right-click nick in chat → `chat_context_menu` event → menu renders with PM, Whois, Copy Nick, Ignore, Add to Address Book, Set Nick Color items in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T015 [P] [US1] Write LiveView test: op user right-clicks nick → op actions (Kick, Ban, Voice, Op) appear; non-op user → op actions hidden in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T016 [P] [US1] Write LiveView test: right-click own nick → self-targeting actions (Kick, Ban, Ignore) are disabled in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T017 [P] [US1] Write LiveView test: clicking menu items dispatches correct actions (PM opens query, Whois executes, Copy pushes clipboard event) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`

### Implementation for User Story 1

- [x] T018 [US1] Create `ChatContextMenu` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex` — attrs: `menu` (map), `viewer_nick` (string), `viewer_is_op` (boolean), `is_target_ignored` (boolean), `is_target_self` (boolean), `is_already_joined` (boolean), `key_bindings` (map). Render nick variant with: PM, Whois, Copy Nick, separator, Ignore/Unignore, Add to Address Book, Set Nick Color, separator (if op), Kick, Ban, Give Voice, Give Op. Each item with `phx-click`, `phx-value-nick`, `data-testid`. Apply disabled class for unavailable items. Display shortcut hints via `KeyBindings.to_display_string/1`. Attach `phx-hook="ContextMenuHook"` for keyboard nav and viewport repositioning
- [x] T019 [US1] Add `handle_event("chat_context_menu", ...)` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — parse payload, determine type, assign `chat_context_menu` map with visibility, position, and target data
- [x] T020 [US1] Add nick action event handlers (`ctx_chat_pm`, `ctx_chat_whois`, `ctx_chat_copy_nick`, `ctx_chat_ignore`, `ctx_chat_add_contact`, `ctx_chat_set_color`, `ctx_chat_kick`, `ctx_chat_ban`, `ctx_chat_voice`, `ctx_chat_op`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — delegate to existing command handlers, push clipboard_copy events where needed, close menu after action
- [x] T021 [US1] Add `close_chat_context_menu` event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — reset `chat_context_menu` assign to default
- [x] T022 [US1] Render `<.chat_context_menu>` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — pass assigns: menu, viewer_nick, viewer_is_op, is_target_ignored, is_target_self, key_bindings. Add `phx-click="close_chat_context_menu"` to chat area container for click-away dismissal
- [x] T023 [US1] Integrate nick color picker — reuse existing color picker pattern from `context_menu.ex` for `ctx_chat_set_color` action in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`

**Checkpoint**: Nick context menu fully functional — right-click nick prefix → menu with all items, shortcuts, disabled states, op filtering, keyboard nav, viewport repositioning.

---

## Phase 4: User Story 2 — URL Context Menu in Chat Area (Priority: P2)

**Goal**: Right-clicking a URL in a chat message shows Open Link, Copy URL, Save to URL List.

**Independent Test**: Right-click any URL in chat → menu appears with 3 items. Open Link opens new tab, Copy URL copies to clipboard, Save adds to URL catcher list.

### Tests for User Story 2

- [x] T024 [P] [US2] Write LiveView test: right-click URL in chat → menu renders with Open Link, Copy URL, Save to URL List in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T025 [P] [US2] Write LiveView test: clicking Save to URL List adds URL to `url_catcher_entries` assign in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`

### Implementation for User Story 2

- [x] T026 [US2] Add URL variant rendering to `ChatContextMenu` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex` — items: Open Link, Copy URL, Save to URL List with `phx-click` and `phx-value-url`
- [x] T027 [US2] Add URL action event handlers (`ctx_chat_open_url`, `ctx_chat_copy_url`, `ctx_chat_save_url`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — push `open_url` event, push `clipboard_copy` event, call `CapturedURL.new/1` and prepend to `url_catcher_entries`

**Checkpoint**: URL context menu functional — Open, Copy, Save all work.

---

## Phase 5: User Story 3 — Channel Name Context Menu in Chat Area (Priority: P3)

**Goal**: Right-clicking a #channel reference in a chat message shows Join Channel, Add to Favorites, Copy Channel Name, Channel Info.

**Independent Test**: Right-click `#general` in chat → menu appears with 4 items. Join Channel grayed out if already joined.

### Tests for User Story 3

- [x] T028 [P] [US3] Write LiveView test: right-click channel reference in chat → menu renders with Join Channel, Add to Favorites, Copy Channel Name, Channel Info in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T029 [P] [US3] Write LiveView test: Join Channel disabled when user is already in that channel in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`

### Implementation for User Story 3

- [x] T030 [US3] Add channel variant rendering to `ChatContextMenu` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex` — items: Join Channel (disabled if already joined), Add to Favorites, Copy Channel Name, Channel Info with `phx-click` and `phx-value-channel`
- [x] T031 [US3] Add channel action event handlers (`ctx_chat_join`, `ctx_chat_fav`, `ctx_chat_copy_channel`, `ctx_chat_channel_info`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — delegate to existing /join handler, add to favorites, push clipboard_copy, open channel info dialog

**Checkpoint**: Channel context menu functional — Join, Favorites, Copy, Info all work. Join disabled when already in channel.

---

## Phase 6: User Story 4 — General Message Context Menu (Priority: P4)

**Goal**: Right-clicking the general chat area (not on nick/URL/channel) shows Copy Message, Copy Selected Text, Quote/Reply (disabled), Ignore Sender. URL items appear if message contains a URL.

**Independent Test**: Right-click empty area of a chat message → menu with Copy Message, Copy Selected Text (grayed if no selection), Quote/Reply (grayed), Ignore Sender. System messages omit Ignore Sender.

### Tests for User Story 4

- [x] T032 [P] [US4] Write LiveView test: right-click general message area → menu renders with Copy Message, Copy Selected Text, Quote/Reply (disabled), Ignore Sender in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T033 [P] [US4] Write LiveView test: system message right-click → Ignore Sender is NOT shown in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T034 [P] [US4] Write LiveView test: message with URL → URL sub-items (Open Link, Copy URL) also appear in message menu in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`

### Implementation for User Story 4

- [x] T035 [US4] Add message variant rendering to `ChatContextMenu` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex` — items: Copy Message (with `phx-value-text` containing formatted `[HH:MM] <Nick> message`), Copy Selected Text (disabled class if `!@menu.has_selection`), Quote/Reply (always disabled class), Ignore Sender (hidden if `@menu.target_message.is_system`). If `@menu.target_message.urls` is non-empty, add separator + Open Link, Copy URL sub-items for the first URL
- [x] T036 [US4] Add message action event handlers (`ctx_chat_copy_message`, `ctx_chat_copy_selection`, `ctx_chat_ignore_sender`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` — push `clipboard_copy` with formatted message text, push `clipboard_copy_selection` for selection copy, delegate to /ignore for sender

**Checkpoint**: Message context menu functional — Copy Message copies formatted line, Copy Selection works with text selection, Ignore Sender works, system messages handled correctly.

---

## Phase 7: User Story 5 — Extended Treebar Context Menu (Priority: P5)

**Goal**: Replace the treebar's minimal context menu (only "Add to Favorites") with extended menu: Mark as Read, Mute Channel, Add to Favorites, Copy Name, Leave Channel, Channel Settings.

**Independent Test**: Right-click channel in treebar → extended menu with 6 items + separator. Mark as Read clears unread. Mute toggles and persists.

### Tests for User Story 5

- [x] T037 [P] [US5] Write LiveView test: right-click treebar channel → extended menu renders with Mark as Read, Mute/Unmute Channel, Add to Favorites, Copy Name, separator, Leave Channel, Channel Settings in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T038 [P] [US5] Write LiveView test: Mark as Read clears unread_channels for that channel in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T039 [P] [US5] Write LiveView test: Mute Channel toggles muted_channels MapSet and persists to user preferences in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`

### Implementation for User Story 5

- [x] T040 [US5] Extend `TreebarContextMenu` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar_context_menu.ex` — add new attrs: `is_muted` (boolean), `has_unread` (boolean), `key_bindings` (map). Replace single "Add to Favorites" item with: Mark as Read (disabled if no unread), Mute Channel / Unmute Channel (toggle label based on `@is_muted`), Add to Favorites, Copy Name, separator, Leave Channel, Channel Settings. Each with `phx-click`, `phx-value-channel`, `data-testid`. Attach `phx-hook="ContextMenuHook"`
- [x] T041 [US5] Add treebar action event handlers (`ctx_treebar_mark_read`, `ctx_treebar_mute`, `ctx_treebar_copy_name`, `ctx_treebar_leave`, `ctx_treebar_settings`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/favorites_events.ex` — mark_read removes from `unread_channels` MapSet; mute toggles `muted_channels` MapSet and persists via `UserPreferences.toggle_mute_channel/2` then `UserPreferences.save/2`; copy_name pushes `clipboard_copy`; leave delegates to /part handler; settings opens channel settings dialog
- [x] T042 [US5] Update treebar context menu rendering in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — pass new attrs `is_muted`, `has_unread`, `key_bindings` to `<.treebar_context_menu>`
- [x] T043 [US5] Integrate mute state with notification suppression — in message PubSub handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`, check `muted_channels` MapSet before triggering sound/flash notifications for incoming messages

**Checkpoint**: Extended treebar context menu functional — all 6 items work, mute state persists, notifications suppressed for muted channels.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, keyboard shortcut hints on existing menus, final integration, CI validation.

- [x] T044 Add keyboard shortcut hint display support to existing nicklist `ContextMenu` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex` — add `key_bindings` attr, render shortcut hints right-aligned on applicable items
- [x] T045 [P] Add "Context Menus" help topic to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — describe all 5 menu types, how to trigger them, keyboard navigation (arrow keys, Enter, Escape), and cross-references to related topics
- [x] T046 [P] Update "Keyboard Shortcuts" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex` — add context menu keyboard navigation (arrow keys, Enter to select, Escape to close)
- [x] T047 Write E2E test for viewport repositioning — right-click near bottom/right edge of viewport, verify menu flips position in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T048 Write E2E test for keyboard navigation — open context menu, arrow down/up, Enter to select, Escape to close in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_test.exs`
- [x] T049 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) — BLOCKS all user stories
- **User Stories (Phases 3–7)**: All depend on Foundational (Phase 2)
  - US1 (P1) can start immediately after Phase 2
  - US2–US4 can start after Phase 2 (they share `ChatContextMenu` component created in US1)
  - US5 can start after Phase 2 (modifies different component — `TreebarContextMenu`)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Creates `ChatContextMenu` component — US2, US3, US4 add variants to this component
- **US2 (P2)**: Adds URL variant to component from US1 — no dependency on US3/US4/US5
- **US3 (P3)**: Adds channel variant to component from US1 — no dependency on US2/US4/US5
- **US4 (P4)**: Adds message variant to component from US1 — no dependency on US2/US3/US5
- **US5 (P5)**: Modifies `TreebarContextMenu` (different component) — can run in parallel with US2–US4

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Component rendering before event handlers
- Event handlers before integration
- Story complete before moving to next priority

### Parallel Opportunities

- Setup tasks T002, T003, T004 can run in parallel (different files)
- Foundational tests T005, T006 can run in parallel
- Within each user story, test tasks marked [P] can run in parallel
- **US5 can run in parallel with US2, US3, or US4** (different components)
- Polish tasks T044, T045, T046 can run in parallel (different files)

---

## Parallel Example: User Story 1

```bash
# Launch all tests for US1 together:
Task: "T014 - Test nick menu renders with correct items"
Task: "T015 - Test op actions hidden for non-ops"
Task: "T016 - Test self-targeting actions disabled"
Task: "T017 - Test menu item actions dispatch correctly"

# After tests fail (red), implement sequentially:
Task: "T018 - Create ChatContextMenu component (nick variant)"
Task: "T019 - Add chat_context_menu event handler"
Task: "T020 - Add nick action event handlers"
Task: "T021 - Add close handler"
Task: "T022 - Render component in template"
Task: "T023 - Integrate nick color picker"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T004)
2. Complete Phase 2: Foundational (T005–T013)
3. Complete Phase 3: User Story 1 (T014–T023)
4. **STOP and VALIDATE**: Right-click nick prefix → full menu with shortcuts, disabled states, op filtering, keyboard nav, viewport repositioning
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (nick menu) → Test independently → **MVP!**
3. Add US2 (URL menu) → Test independently
4. Add US3 (channel menu) → Test independently
5. Add US4 (message menu) → Test independently
6. Add US5 (extended treebar) → Test independently (can run in parallel with US2–US4)
7. Polish → Help docs, shortcuts on existing menus, CI validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD — Constitution Principle IV)
- The `ChatContextMenu` component is created in US1 and extended with variants in US2–US4
- The `TreebarContextMenu` component is modified independently in US5
- Total test count: 17 test tasks + 2 E2E tests = 19 test points
