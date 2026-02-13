# Tasks: Options Dialog (021)

**Input**: Design documents from `/specs/021-options-dialog/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/liveview-events.md, quickstart.md

**Tests**: TDD is non-negotiable (Constitution Principle IV). Domain tests FIRST, then implementation. Web/E2E tests in Polish phase.

**Organization**: Tasks grouped by user story. 6 user stories (P1-P6) matching the 6 panels, plus foundation and polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain**: `apps/retro_hex_chat/lib/retro_hex_chat/`
- **Web**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`
- **Assets**: `apps/retro_hex_chat_web/assets/`

---

## Phase 1: Setup

**Purpose**: Branch creation and environment verification

- [x] T001 Create and checkout `021-options-dialog` branch from `main`, verify `mix compile` and `mix test --include e2e` pass cleanly

---

## Phase 2: Foundation (Domain + Migration + Session)

**Purpose**: Core domain modules, database migration, and session extension that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

### Tests (write FIRST, verify they FAIL)

- [x] T002 [P] Write UserPreferences domain module tests (new/0 defaults, get/set for all 6 categories, to_css_styles output, atom/string key conversion, save/load round-trip) in `apps/retro_hex_chat/test/retro_hex_chat/chat/user_preferences_test.exs`
- [x] T003 [P] Write KeyBindings domain module tests (defaults/0 returns 9 bindings, find_action/2 lookup, conflict?/3 detection, reserved?/1 for Ctrl+W/T/N/L/Tab/H/J/D, to_display_string/1 formatting, actions/0 list) in `apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs`

### Implementation

- [x] T004 Create migration for `user_preferences` table (owner_nickname PK → registered_nicks FK, 6 JSONB columns: display_settings, font_settings, color_settings, connect_settings, message_settings, key_bindings, timestamps) in `apps/retro_hex_chat/priv/repo/migrations/`
- [x] T005 [P] Create UserPreference Ecto schema with 6 map fields and changeset validation in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/user_preference.ex`
- [x] T006 [P] Implement UserPreferences domain module (new/0 with all defaults from data-model.md, get_*/1 accessors, set_display/3, set_font/3, set_color/3, set_nick_palette_color/3, set_connect/3, set_routing/3, set_key_binding/3, to_css_styles/1 → CSS property map, save/2, load/1 with atom↔string key conversion) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex`
- [x] T007 [P] Implement KeyBindings domain module (defaults/0 → 9 default bindings map, actions/0 → action labels, find_action/2 → match key+modifiers to action, conflict?/3 → check for duplicate bindings, reserved?/1 → browser-reserved combos list, to_display_string/1 → "Alt+B" format, validate/1 → ensure no conflicts) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex`
- [x] T008 Extend Session struct with `user_preferences` field (default: `UserPreferences.new()`) and add getter/setter in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [x] T009 Integrate UserPreferences.load/1 into `load_persisted_data/2` using existing `load_if_found` pattern, setting `session.user_preferences` on NickServ identify in ChatLive persistence helper

**Checkpoint**: Foundation ready — `mix test` passes, migration runs, domain modules have full test coverage

---

## Phase 3: User Story 1 — Dialog Shell + Display Panel (Priority: P1) MVP

**Goal**: Deliver the Options dialog shell with tree-view navigation, Display panel with 6 toggles, and Apply/OK/Cancel pattern. Users can toggle toolbar, treebar, switchbar, statusbar visibility, enable compact mode and line shading.

**Independent Test**: Open dialog via Alt+O, toggle Display settings, click Apply, verify UI elements show/hide and line shading appears.

### Implementation

- [x] T010 [US1] Create OptionsDialog function component with tree-view navigation (6 categories), panel switching via `options_panel` assign, OK/Cancel/Apply button bar, and Display panel (6 checkboxes: show_toolbar, show_treebar, show_switchbar, show_statusbar, compact_mode, line_shading) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T011 [US1] Create OptionsEvents handler module with attach_hook pattern: handle open_options_dialog (create draft from live prefs), close_options_dialog (discard draft), options_ok (apply+close), options_apply (apply, keep open), options_select_panel, options_toggle_display in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T012 [US1] Integrate OptionsDialog into ChatLive: add assigns (show_options_dialog, options_panel, options_draft, show_toolbar, show_switchbar, show_statusbar, compact_mode, line_shading, key_bindings) to assign_defaults, attach OptionsEvents hook, add component to template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T013 [US1] Wrap toolbar, tab-bar (switchbar), and status-bar in `:if` conditionals using show_toolbar/show_switchbar/show_statusbar assigns, add `compact-mode` and `chat-line-shading` CSS classes to containers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T014 [P] [US1] Add CSS rules for line shading (`.chat-line-shading .chat-message:nth-child(even)` with subtle background), compact mode (`.compact-mode` reducing padding/margins), and options dialog layout (`.options-dialog`, `.options-tree`, `.options-panel`, `.options-buttons`) in `apps/retro_hex_chat_web/assets/css/layout.css` and `apps/retro_hex_chat_web/assets/css/chat.css`
- [x] T015 [US1] Wire menu bar "Options..." item in Tools menu and toolbar Settings button to `open_options_dialog` event in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`
- [x] T016 [US1] Write LiveView tests for dialog shell + display panel (open/close, panel switching, display toggles, apply/cancel/ok, duplicate prevention, draft discard on cancel) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs`

**Checkpoint**: Options dialog opens, Display panel works, Apply/OK/Cancel pattern functional. User Story 1 independently testable.

---

## Phase 4: User Story 2 — Fonts Panel (Priority: P2)

**Goal**: Deliver font customization for 4 text areas (chat messages, input box, nicklist, treebar) with live preview. Introduce CSS custom properties and OptionsHook for real-time style application.

**Independent Test**: Open Options > Fonts, change chat messages font size, verify preview updates, click Apply, confirm chat text renders with new font.

### Implementation

- [x] T017 [US2] Introduce CSS custom properties for all font values (--chat-font-family, --chat-font-size, --input-font-family, --input-font-size, --nicklist-font-family, --nicklist-font-size, --treebar-font-family, --treebar-font-size) with fallback defaults, replace hardcoded font declarations with var() references in `apps/retro_hex_chat_web/assets/css/layout.css`, `apps/retro_hex_chat_web/assets/css/chat.css`, and `apps/retro_hex_chat_web/assets/css/components.css`
- [x] T018 [US2] Create OptionsHook JS hook that handles `apply_preferences` push_event, iterates style map entries and calls `document.documentElement.style.setProperty(name, value)` for each, also handles mounted/reconnected to request current styles in `apps/retro_hex_chat_web/assets/js/hooks/options_hook.js`
- [x] T019 [US2] Register OptionsHook in app.js, add `id="options-hook" phx-hook="OptionsHook"` element to ChatLive template, push `apply_preferences` event on mount with current font styles in `apps/retro_hex_chat_web/assets/js/app.js` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [x] T020 [US2] Implement Fonts panel UI in OptionsDialog component: 4 areas (chat_messages, input_box, nicklist, treebar) each with font family select (5 options from data-model.md) and size select (8-24px), plus live preview div with sample text styled from draft fonts in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T021 [US2] Add options_change_font event handler (update draft fonts for area), extend options_apply/options_ok to push_event("apply_preferences") with font CSS properties from UserPreferences.to_css_styles/1 in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T022 [US2] Write LiveView tests for Fonts panel (font family/size change, preview update, apply pushes styles, scroll position preserved after font change) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs`

**Checkpoint**: Fonts panel fully functional. Font changes apply in real time via CSS custom properties.

---

## Phase 5: User Story 3 — Colors Panel (Priority: P3)

**Goal**: Deliver color customization for 6 UI slots plus 16-color nick palette. Extend CSS custom properties and OptionsHook for color changes.

**Independent Test**: Open Options > Colors, change chat background color, click Apply, verify chat area background updates.

### Implementation

- [x] T023 [US3] Introduce CSS custom properties for all color values (--chat-bg-color, --default-text-color, --own-messages-color, --system-messages-color, --timestamps-color, --error-messages-color, --irc-color-0 through --irc-color-15) with fallback defaults, replace hardcoded colors with var() in `apps/retro_hex_chat_web/assets/css/chat.css` and `apps/retro_hex_chat_web/assets/css/layout.css`
- [x] T024 [US3] Implement Colors panel UI in OptionsDialog: 6 named color slots (each shows swatch + label, click opens picker), nick palette section (4x4 grid of 16 IRC color swatches, click opens picker), 24-color picker grid component (4x6 grid, 16 IRC + 8 additional preset colors) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T025 [US3] Add options_change_color and options_change_nick_color event handlers, extend options_apply to include color CSS properties in push_event("apply_preferences") in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T026 [US3] Write LiveView tests for Colors panel (color slot change, nick palette change, picker interaction, apply updates CSS properties, cancel discards color changes) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs`

**Checkpoint**: Colors panel fully functional. Color changes apply in real time.

---

## Phase 6: User Story 4 — Connect Panel (Priority: P4)

**Goal**: Deliver reconnect settings configuration. Pass dynamic parameters to ReconnectHook via push_event.

**Independent Test**: Open Options > Connect, change retry interval, click Apply, verify reconnect behavior uses new settings.

### Implementation

- [x] T027 [US4] Implement Connect panel UI in OptionsDialog: auto_reconnect_enabled toggle, retry_interval number input (1-60), max_retries number input (1-100), connection_timeout number input (5-120), with validation feedback in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T028 [US4] Add options_change_connect event handler with validation (clamp values to ranges), extend options_apply to push_event("reconnect_config") with dynamic params in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T029 [US4] Modify ReconnectHook.js to handle "reconnect_config" push_event: store enabled/max_attempts/max_delay/timeout in instance variables, use them instead of hardcoded values, skip reconnection if enabled=false in `apps/retro_hex_chat_web/assets/js/hooks/reconnect_hook.js`
- [x] T030 [US4] Push reconnect_config on mount (from current user_preferences.connect) and on apply in ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T031 [US4] Write LiveView tests for Connect panel (setting changes, validation clamping, apply pushes reconnect_config, cancel discards) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs`

**Checkpoint**: Connect panel fully functional. Reconnect behavior dynamically configurable.

---

## Phase 7: User Story 5 — IRC Messages Panel (Priority: P5)

**Goal**: Deliver message routing preferences for whois, notices, and PMs. Sync notice_routing with existing Session field.

**Independent Test**: Open Options > IRC Messages, change notice routing to "Status Window", click Apply, receive a notice — verify it appears in Status tab.

### Implementation

- [x] T032 [US5] Implement IRC Messages panel UI in OptionsDialog: whois_routing select (active/dialog), notice_routing select (active/status/sender), pm_routing select (new_tab/active), with descriptions for each option in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T033 [US5] Add options_change_routing event handler, sync notice_routing changes with existing Session.notice_routing field and notice_routing_settings persistence, wire whois and PM routing into ChatLive message handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T034 [US5] Write LiveView tests for IRC Messages panel (routing select changes, notice routing sync with existing session field, apply persists, cancel discards) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs`

**Checkpoint**: IRC Messages panel fully functional. Message routing configurable.

---

## Phase 8: User Story 6 — Key Bindings Panel (Priority: P6)

**Goal**: Deliver keyboard shortcut customization with key capture, conflict detection, browser-reserved key rejection, and Reset to Defaults. Refactor keyboard_events.ex to dynamic lookup.

**Independent Test**: Open Options > Key Bindings, click an action, press new key combo, verify conflict warnings, apply, confirm new shortcut works.

### Implementation

- [x] T035 [US6] Create KeyBindingCaptureHook JS hook: listen for keydown in capture mode, extract key + modifiers (alt/ctrl/shift), send "options_capture_key" push to server, display "Press a key combination..." placeholder, prevent default on capture in `apps/retro_hex_chat_web/assets/js/hooks/key_binding_capture_hook.js`
- [x] T036 [US6] Register KeyBindingCaptureHook in app.js in `apps/retro_hex_chat_web/assets/js/app.js`
- [x] T037 [US6] Implement Key Bindings panel UI in OptionsDialog: scrollable action list (action label + current binding display), selected row highlight with "Press a key combination..." prompt, conflict warning display, clear binding button per action, Reset to Defaults button with confirmation dialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T038 [US6] Add key binding event handlers (options_select_binding, options_capture_key with conflict detection via KeyBindings.conflict?/3 and reserved check via KeyBindings.reserved?/1, options_clear_binding, options_reset_bindings with confirmation) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [x] T039 [US6] Refactor keyboard_events.ex from hardcoded pattern matching to dynamic lookup: replace individual handle_event clauses with single clause that extracts key+modifiers, calls KeyBindings.find_action/2 on socket.assigns.key_bindings, dispatches to handler function via action_id in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/keyboard_events.ex`
- [x] T040 [US6] Write LiveView tests for Key Bindings panel (action selection, key capture, conflict warning, browser-reserved rejection, clear binding, reset to defaults, dynamic lookup dispatch) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs`

**Checkpoint**: Key Bindings panel fully functional. All keyboard shortcuts dynamically configurable.

---

## Phase 9: Help + Polish

**Purpose**: Help documentation, E2E tests, data-testid attributes, linter verification

- [x] T041 [P] Add help topics to HelpTopics: "feature-options-dialog" (overview of all 6 panels), "feature-display-settings" (toolbar/treebar/switchbar/statusbar/compact/line-shading), "feature-key-bindings" (customization how-to), update "keyboard-shortcuts" topic with note about customization via Options in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [x] T042 [P] Add data-testid attributes to all OptionsDialog elements (tree items, panel containers, toggle checkboxes, select inputs, color swatches, action rows, buttons) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex`
- [x] T043 Write E2E tests covering: open/close dialog, panel navigation, display toggle apply, font change apply, color change apply, connect settings apply, message routing apply, key binding reassign, conflict warning, reset to defaults, persistence for registered user, guest session persistence, duplicate prevention in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/options_dialog_e2e_test.exs`
- [x] T044 Run full CI-equivalent validation: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `mix test --include e2e`, `mix dialyzer`
- [x] T045 Fix any linter warnings, test failures, or dialyzer errors found in T044 (fixed: dialyzer spec for nil binding, Credo apply_font_change complexity refactor, alias in test, format)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundation (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1-US6 (Phases 3-8)**: All depend on Phase 2 completion
  - US1 (Display) can start immediately after Phase 2
  - US2 (Fonts) depends on US1 (dialog shell must exist)
  - US3 (Colors) depends on US2 (OptionsHook + CSS custom properties infrastructure)
  - US4 (Connect) depends on US1 (dialog shell)
  - US5 (Messages) depends on US1 (dialog shell)
  - US6 (Key Bindings) depends on US1 (dialog shell)
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundation only — MVP, establishes dialog shell
- **US2 (P2)**: US1 + Foundation — introduces CSS custom properties + OptionsHook
- **US3 (P3)**: US2 — extends CSS custom properties for colors (reuses OptionsHook)
- **US4 (P4)**: US1 + Foundation — independent of US2/US3 (uses ReconnectHook, not OptionsHook)
- **US5 (P5)**: US1 + Foundation — independent of US2/US3/US4
- **US6 (P6)**: US1 + Foundation — independent of US2-US5, refactors keyboard_events.ex

### Within Each User Story

- Component UI changes depend on dialog shell from US1
- Event handlers depend on OptionsEvents module from US1
- CSS custom property extension (US3) depends on initial introduction (US2)
- Tests can be written alongside implementation (TDD within each task)

### Parallel Opportunities

- T002 + T003 (foundation tests) can run in parallel
- T005 + T006 + T007 (schema + domain modules) can run in parallel
- After US1 is complete: US4, US5, US6 can run in parallel (independent panels)
- US2 must precede US3 (CSS custom properties dependency)
- T041 + T042 (help topics + data-testid) can run in parallel

---

## Parallel Example: Foundation Phase

```bash
# Write domain tests in parallel:
Task: "UserPreferences tests in apps/retro_hex_chat/test/retro_hex_chat/chat/user_preferences_test.exs"
Task: "KeyBindings tests in apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs"

# Implement domain modules in parallel (after tests):
Task: "UserPreference Ecto schema in apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/user_preference.ex"
Task: "UserPreferences module in apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex"
Task: "KeyBindings module in apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex"
```

## Parallel Example: After US1 Complete

```bash
# These three user stories can be worked on in parallel:
Task: "US4 Connect panel (Phase 6) — independent of font/color CSS vars"
Task: "US5 Messages panel (Phase 7) — independent of other panels"
Task: "US6 Key Bindings panel (Phase 8) — independent, refactors keyboard_events.ex"

# US2 and US3 must be sequential (CSS custom properties dependency)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundation (migration, domain modules, session)
3. Complete Phase 3: User Story 1 (dialog shell + display panel)
4. **STOP and VALIDATE**: Test dialog open/close, display toggles, apply/cancel/ok
5. Dialog delivers immediate value — workspace customization

### Incremental Delivery

1. Setup + Foundation → Domain layer ready
2. US1 (Display Panel) → Dialog shell established, workspace toggles → **MVP**
3. US2 (Fonts Panel) → CSS custom properties introduced, font customization
4. US3 (Colors Panel) → Color customization extends CSS var infrastructure
5. US4 (Connect) → Reconnect settings configurable (can parallel with US2/US3)
6. US5 (Messages) → Message routing configurable (can parallel with US2/US3)
7. US6 (Key Bindings) → Keyboard shortcuts customizable (most complex panel)
8. Polish → Help topics, E2E tests, data-testid, linter verification

### Critical Path

```
Setup → Foundation → US1 (Dialog Shell) → US2 (Fonts/CSS vars) → US3 (Colors)
                                        → US4 (Connect) ─────────────────────→ Polish
                                        → US5 (Messages) ────────────────────→
                                        → US6 (Key Bindings) ────────────────→
```

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Draft state pattern: open copies live→draft, edits modify draft only, Apply writes draft→live+persist, Cancel discards
- CSS custom properties: introduced in US2 (fonts), extended in US3 (colors), applied via OptionsHook push_event
- Dynamic key bindings: keyboard_events.ex refactored in US6, uses runtime lookup instead of pattern matching
- Total tasks: 45 (1 setup + 8 foundation + 7 US1 + 6 US2 + 4 US3 + 5 US4 + 3 US5 + 6 US6 + 5 polish)
