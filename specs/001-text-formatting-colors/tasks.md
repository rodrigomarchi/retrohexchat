# Tasks: Text Formatting & Colors

**Input**: Design documents from `/specs/001-text-formatting-colors/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Required by Constitution Principle IV (TDD is non-negotiable). Tests are written first.

**Organization**: Tasks grouped by user story. US1 and US2 share a foundation (the parser) so they are combined into a single phase since they are both P1 and inseparable at the parser level.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Foundational (Parser + Domain Extensions)

**Purpose**: Build the core mIRC format code parser, extend policy validation, and extend session — the domain foundation that all user stories depend on.

**CRITICAL**: No user story UI work can begin until this phase is complete.

### Tests First

- [x] T001 [P] Write unit tests for `Formatter.strip/1` covering all 7 control codes, color code digit stripping, bare 0x03 reset, zero-padded colors, and plain text passthrough in `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`
- [x] T002 [P] Write unit tests for `Formatter.to_safe_html/1` covering bold, italic, underline, strikethrough, reverse, color (fg only, fg+bg), reset, combined formats, nested formats, unclosed codes, and HTML escaping of user text in `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`
- [x] T003 [P] Write unit tests for `Formatter.has_visible_text?/1` and `Formatter.count_codes/1` covering format-only content, whitespace-only after strip, mixed content, and code counting in `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`
- [x] T004 [P] Write StreamData property tests for `Formatter`: (1) `strip/1` output never contains control characters, (2) `to_safe_html/1` preserves all visible text from `strip/1`, (3) plain text input passes through without span wrapping in `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`
- [x] T005 [P] Write unit tests for edge cases: malformed color codes (non-numeric after 0x03), color "16" parsed as color 1 + literal "6", 128-code soft limit (excess codes stripped, text preserved), empty string input, and messages with only whitespace after stripping in `apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`
- [x] T006 [P] Write unit tests for `Policy.validate_content/1` extension: format-code-only messages rejected, format-codes + whitespace-only rejected, format-codes + visible text accepted, plain text unchanged behavior in `apps/retro_hex_chat/test/retro_hex_chat/chat/policy_test.exs`
- [x] T007 [P] Write unit tests for `Session.toggle_strip_formatting/1`: default is false, toggle flips to true, toggle again flips back in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`

### Implementation

- [x] T008 Implement `Chat.Formatter` module with `strip/1`, `to_safe_html/1`, `has_visible_text?/1`, `visible_text/1`, and `count_codes/1` using internal state machine (FormatterState) for parsing. Include color palette constant, color code parser (up to 2 digits fg, optional comma + 2 digits bg), HTML escaping via `Phoenix.HTML.html_escape/1`, span wrapping with `irc-*` CSS classes, 128-code soft limit via `:max_codes` option, and `@spec` on all public functions in `apps/retro_hex_chat/lib/retro_hex_chat/chat/formatter.ex`
- [x] T009 Extend `Policy.validate_content/1` to call `Formatter.has_visible_text?/1` after existing length checks — reject messages where visible text is empty or whitespace-only in `apps/retro_hex_chat/lib/retro_hex_chat/chat/policy.ex`
- [x] T010 Add `strip_formatting` boolean field (default: `false`) to `Session` struct and `@type t`, implement `toggle_strip_formatting/1` with `@spec` in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [x] T011 Run `make test` and `make lint` to verify all foundational tests pass and static analysis is clean

**Checkpoint**: Parser fully tested, policy extended, session extended. All domain code complete.

---

## Phase 2: User Stories 1 & 2 — Inline Formatting + Colors (Priority: P1) MVP

**Goal**: Users can send messages with mIRC format codes (bold, italic, underline, strikethrough, reverse, colors, reset) via keyboard shortcuts and see them rendered with correct visual styles.

**Independent Test**: Type a message with Ctrl+B wrapped text and Ctrl+K color codes, send it, verify recipient sees bold + colored text.

### Tests First

- [x] T012 [P] [US1] Write LiveView tests: sending a message with bold control codes renders `<span class="irc-bold">` in chat output; italic renders `irc-italic`; underline renders `irc-underline`; system/service/error messages are NOT parsed for format codes in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`
- [x] T013 [P] [US2] Write LiveView tests: sending a message with color codes renders `<span class="irc-fg-4">` for red; fg+bg renders both `irc-fg-4 irc-bg-1`; combined bold+color renders both classes in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`

### Implementation

- [x] T014 [P] [US1] Add all IRC formatting CSS classes to dark-theme.css: `.irc-bold`, `.irc-italic`, `.irc-underline`, `.irc-strikethrough`, `.irc-reverse-default`, combined `.irc-underline.irc-strikethrough`, and formatting toolbar + color picker placeholder styles in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T015 [P] [US2] Add all 16 foreground color classes (`.irc-fg-0` through `.irc-fg-15`) and all 16 background color classes (`.irc-bg-0` through `.irc-bg-15`) with correct hex values from the mIRC color palette in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T016 [US1] Update ChatLive template to render formatted messages: for `:message` and `:action` types, call `Formatter.to_safe_html(msg.content)` and render with `raw/1`; for `:system`, `:service`, `:error` types, render as-is (no format parsing). Import `Chat.Formatter` alias in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T017 [US1] Add formatting keyboard shortcut handling to the chat input hook: intercept Ctrl+B (0x02), Ctrl+I (0x1D), Ctrl+U (0x1F), Ctrl+R (0x16), Ctrl+K (0x03), Ctrl+O (0x0F) keydown events, `preventDefault()`, insert the control character at cursor position, dispatch `input` event for LiveView tracking. Compose with existing CommandPaletteHook logic (LiveView single-hook limitation) in `apps/retro_hex_chat_web/assets/js/hooks/command_palette_hook.js`
- [x] T018 [US1] Run `make test` and `make lint` to verify US1+US2 LiveView tests pass and static analysis is clean

**Checkpoint**: Users can type formatted messages with keyboard shortcuts and see bold/italic/underline/strikethrough/reverse/color rendering. Format codes stored verbatim in DB. System messages not parsed. This is the MVP.

---

## Phase 3: User Story 3 — Formatting Toolbar (Priority: P2)

**Goal**: Visual formatting toolbar with B/I/U buttons and dropdown color picker above the input box, inserting format codes at cursor without stealing focus.

**Independent Test**: Click the Bold button, verify control code appears in input, send message, confirm bold rendering.

### Tests First

- [x] T019 [P] [US3] Write LiveView tests: formatting toolbar is rendered in chat view with Bold, Italic, Underline, and Color buttons (verify `data-testid` attributes); toolbar has correct 98.css styling classes in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`
- [x] T020 [P] [US3] Write LiveView tests: color picker dropdown contains 16 color swatches in a grid; each swatch has `data-color-code` attribute with correct index (0-15) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`

### Implementation

- [x] T021 [US3] Create `FormattingToolbar` function component with Bold (B), Italic (I), Underline (U) buttons and Color button with hidden 4x4 dropdown grid of 16 color swatches. Use `data-format-code` attributes for format buttons, `data-color-code` for swatches, `data-testid` for testing. Style with 98.css conventions (raised panel, button styling) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/formatting_toolbar.ex`
- [x] T022 [US3] Add formatting toolbar and color picker CSS styles: `.formatting-toolbar` container, `.format-btn` buttons (22x22px, 98.css style), `.format-color-picker-wrapper` relative container, `.format-color-dropdown` absolute 4x4 grid, `.color-swatch` 16x16px buttons with hover state in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T023 [US3] Create `FormatToolbarHook` JS hook: handle `mousedown` (not click) on `.format-btn` elements with `preventDefault()` to avoid input blur; read `data-format-code` and insert at `#chat-input` cursor position; toggle color dropdown on Color button mousedown; insert `\x03` + swatch `data-color-code` on swatch mousedown; dismiss dropdown on outside click or Escape in `apps/retro_hex_chat_web/assets/js/hooks/format_toolbar_hook.js`
- [x] T024 [US3] Register `FormatToolbarHook` in app.js and render `<.formatting_toolbar />` in ChatLive template between chat messages area and input form. Import component in ChatLive in `apps/retro_hex_chat_web/assets/js/app.js` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T025 [US3] Run `make test` and `make lint` to verify US3 tests pass and static analysis is clean

**Checkpoint**: Formatting toolbar visible with B/I/U/Color buttons. Color dropdown opens/closes. Clicking buttons inserts format codes without losing focus. All previous functionality still works.

---

## Phase 4: User Story 4 — Strip Formatting Codes Preference (Priority: P3)

**Goal**: Per-user session toggle to strip all formatting from incoming messages, displaying plain text only.

**Independent Test**: Enable strip option, receive a bold+colored message, verify it displays as plain text.

### Tests First

- [x] T026 [P] [US4] Write LiveView tests: when `strip_formatting` is true in session, formatted messages render as plain text (no `irc-*` spans); when false, formatting is rendered; toggle event flips the preference; sent messages still stored with format codes in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`

### Implementation

- [x] T027 [US4] Add `handle_event("toggle_strip_formatting", ...)` to ChatLive: toggle `session.strip_formatting` via `Session.toggle_strip_formatting/1`, update session in socket assigns, and trigger re-render of chat messages (stream reset to re-apply formatting/stripping) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T028 [US4] Update ChatLive template to conditionally render: when `@session.strip_formatting` is true, use `Formatter.strip(msg.content)` instead of `Formatter.to_safe_html(msg.content)` for `:message` and `:action` type messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T029 [US4] Add "Strip Colors" toggle UI control — a checkbox-style toolbar button or menu item that sends `toggle_strip_formatting` event. Reflect active state visually (pressed/depressed button or checkmark) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T030 [US4] Run `make test` and `make lint` to verify US4 tests pass and static analysis is clean

**Checkpoint**: Users can toggle strip-formatting on/off. Formatted messages appear as plain text when enabled. Preference is per-session (resets on reconnect).

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Integration verification, PM formatting, E2E tests, and final quality pass.

- [x] T031 Verify formatting works identically in private messages: send formatted PM, verify recipient sees correct styling; test strip preference applies to PMs too in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs`
- [x] T032 Write E2E tests: full send/receive flow with bold+color formatting, toolbar button click flow, strip toggle flow, edge case: format-only message rejected in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/e2e_test.exs`
- [x] T033 Run full test suite (`make test`), all linters (`make lint` — format, credo strict, dialyzer), verify zero failures and zero warnings
- [x] T034 Run `make test.all` (including E2E) to verify end-to-end functionality

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundational)**: No dependencies — start immediately
- **Phase 2 (US1+US2 MVP)**: Depends on Phase 1 completion (parser must exist for template rendering)
- **Phase 3 (US3 Toolbar)**: Depends on Phase 2 (toolbar inserts codes that must be renderable)
- **Phase 4 (US4 Strip)**: Depends on Phase 2 (strip requires formatter and template changes)
- **Phase 5 (Polish)**: Depends on all previous phases

### User Story Dependencies

- **US1 + US2 (P1)**: Combined because they share the same parser. Can start after Phase 1.
- **US3 (P2)**: Can start after Phase 2. Independent of US4.
- **US4 (P3)**: Can start after Phase 2. Independent of US3.
- **US3 and US4 can run in parallel** after Phase 2 completes.

### Within Each Phase

- Tests MUST be written and FAIL before implementation (Constitution IV)
- Domain code before web code
- CSS before template changes
- JS hooks before template integration
- Verification (`make test && make lint`) at each checkpoint

### Parallel Opportunities

**Phase 1**:
- T001, T002, T003, T004, T005 (all formatter tests) can run in parallel
- T006 (policy tests) and T007 (session tests) can run in parallel with formatter tests
- T008 must wait for all tests to be written (TDD: red phase first)

**Phase 2**:
- T012 and T013 (LiveView tests) can run in parallel
- T014 and T015 (CSS) can run in parallel
- T016 and T017 depend on CSS being in place

**Phase 3 & 4**: Can run entirely in parallel with each other after Phase 2

---

## Parallel Example: Phase 1

```text
# All test files can be written simultaneously (different describe blocks):
T001: Formatter.strip/1 tests
T002: Formatter.to_safe_html/1 tests
T003: Formatter.has_visible_text?/1 + count_codes/1 tests
T004: StreamData property tests
T005: Edge case tests
T006: Policy.validate_content/1 tests (different file)
T007: Session.toggle_strip_formatting/1 tests (different file)

# Then implement sequentially:
T008: Chat.Formatter (makes T001-T005 pass)
T009: Chat.Policy extension (makes T006 pass)
T010: Session extension (makes T007 pass)
T011: Verify all green
```

## Parallel Example: After Phase 2

```text
# US3 and US4 can proceed in parallel:
Developer A: T019 → T020 → T021 → T022 → T023 → T024 → T025
Developer B: T026 → T027 → T028 → T029 → T030
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2)

1. Complete Phase 1: Parser + Domain (T001–T011)
2. Complete Phase 2: US1+US2 CSS + Template + Hooks (T012–T018)
3. **STOP and VALIDATE**: Users can send/receive formatted messages with keyboard shortcuts
4. This is the minimum viable feature — formatting works end-to-end

### Incremental Delivery

1. Phase 1 + Phase 2 → MVP: Formatting works via keyboard shortcuts
2. Add Phase 3 (US3) → Toolbar makes formatting discoverable
3. Add Phase 4 (US4) → Strip preference for users who prefer plain text
4. Phase 5 → E2E tests, PM verification, final quality pass

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- US1 and US2 are combined in Phase 2 because they share the parser and CSS (both P1)
- Constitution IV requires TDD — all test tasks must be completed before their implementation tasks
- The `CommandPaletteHook` must be extended (not replaced) for formatting shortcuts due to LiveView's single-hook-per-element limitation
- No database migrations needed — format codes stored in existing `content` column
- Total: 34 tasks across 5 phases
