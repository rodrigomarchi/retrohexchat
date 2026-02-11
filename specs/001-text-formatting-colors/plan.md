# Implementation Plan: Text Formatting & Colors

**Branch**: `001-text-formatting-colors` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-text-formatting-colors/spec.md`

## Summary

Implement mIRC-compatible text formatting for RetroHexChat: a server-side parser (`Chat.Formatter`) that converts mIRC control codes (bold, italic, underline, strikethrough, reverse, color, reset) into safe HTML spans with CSS classes; keyboard shortcuts (Ctrl+B/I/U/K/R/O) via a JS hook that inserts control characters into the input; a Windows 98-style formatting toolbar with a dropdown color picker; per-user strip-formatting session preference; and validation to reject format-code-only messages. No database migrations required — format codes are stored inline in the existing `content` field.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.7+, Phoenix LiveView 1.0+, 98.css
**Storage**: PostgreSQL 16+ (existing schema, no migrations)
**Testing**: ExUnit, Mox, ExMachina, StreamData, Floki
**Target Platform**: Web (LiveView server-rendered)
**Project Type**: Umbrella app (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Parser must handle 1000-char messages with up to 128 format codes without perceptible delay
**Constraints**: Zero JS UI frameworks (Constitution I), minimal JS hooks only (Constitution VII)
**Scale/Scope**: ~8 files modified, ~5 files created, ~0 migrations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | Parser in Elixir, rendering via LiveView, JS hooks minimal |
| II. Umbrella with Bounded Contexts | PASS | Formatter in Chat context, Session in Accounts, toolbar in Web layer |
| III. OTP Process Architecture | N/A | No new processes needed — formatting is stateless |
| IV. Test-First Development | PASS | StreamData for parser, unit tests for all new functions, LiveView tests for rendering |
| V. Contracts and Behaviours | PASS | Formatter contract defined; no new command handlers |
| VI. Static Analysis | PASS | @spec on all public functions, Credo/Dialyzer enforced |
| VII. Lean LiveViews | PASS | ChatLive delegates to Formatter; JS hooks for keyboard/toolbar only |
| VIII. Windows 98 Fidelity | PASS | Toolbar uses 98.css conventions; monospace font in formatted text |
| IX. Hot/Cold Data Separation | PASS | strip_formatting in Session (hot); format codes in DB content (cold) |
| X. Scalable Architecture | PASS | Stateless parser, no new processes, no new tables |

**Post-Phase 1 Re-check**: All gates PASS. No violations to track.

## Project Structure

### Documentation (this feature)

```text
specs/001-text-formatting-colors/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 research decisions
├── data-model.md        # Data model (no new tables)
├── quickstart.md        # Developer quickstart guide
├── contracts/           # API contracts
│   ├── chat-formatter.md
│   ├── css-classes.md
│   ├── format-hook.md
│   ├── formatting-toolbar-component.md
│   ├── policy-extension.md
│   └── session-extension.md
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
apps/
├── retro_hex_chat/                          # Domain layer
│   ├── lib/retro_hex_chat/
│   │   ├── accounts/
│   │   │   └── session.ex                   # MODIFY: add strip_formatting field
│   │   └── chat/
│   │       ├── formatter.ex                 # NEW: mIRC format code parser
│   │       └── policy.ex                    # MODIFY: reject format-only messages
│   └── test/retro_hex_chat/
│       ├── accounts/
│       │   └── session_test.exs             # MODIFY: strip_formatting tests
│       └── chat/
│           ├── formatter_test.exs           # NEW: comprehensive parser tests
│           └── policy_test.exs              # MODIFY: format-only rejection tests
│
└── retro_hex_chat_web/                      # Web layer
    ├── lib/retro_hex_chat_web/
    │   ├── components/
    │   │   └── formatting_toolbar.ex        # NEW: toolbar component
    │   └── live/
    │       └── chat_live.ex                 # MODIFY: template + strip toggle
    ├── assets/
    │   ├── js/
    │   │   ├── app.js                       # MODIFY: register new hooks
    │   │   └── hooks/
    │   │       ├── format_hook.js           # NEW: keyboard shortcuts
    │   │       └── format_toolbar_hook.js   # NEW: toolbar interaction
    │   └── css/
    │       └── dark-theme.css               # MODIFY: add irc-* + toolbar classes
    └── test/retro_hex_chat_web/
        └── live/
            └── chat_live_test.exs           # MODIFY: formatting render + toolbar tests
```

**Structure Decision**: Existing umbrella structure. New `Chat.Formatter` module in the Chat bounded context. New `FormattingToolbar` component in the web layer. Two new JS hooks for keyboard and toolbar interaction. No new bounded contexts, no new OTP processes, no new database tables.

## Design Decisions

### D1: Server-side formatting parser (not client-side JS)

The `Chat.Formatter` module parses mIRC control codes and produces Phoenix HTML-safe values with `<span class="irc-*">` wrappers. All user text is HTML-escaped before wrapping, preventing XSS.

**Why**: Testable with ExUnit + StreamData (Constitution IV), no JS framework needed (Constitution I), sanitization controlled server-side. LiveView's server rendering sends formatted HTML as part of the diff.

### D2: CSS classes (not inline styles) for formatting

Format codes map to CSS classes (`irc-bold`, `irc-fg-4`, `irc-bg-1`) rather than inline styles. This enables easy theming and override via user stylesheets.

**Why**: Separation of concerns. CSS classes can be adjusted for dark-theme contrast without changing the parser. Inline styles from user input would be an XSS vector.

### D3: Two separate JS hooks (not merged into CommandPaletteHook)

`FormatHook` handles Ctrl+B/I/U/K/R/O keyboard shortcuts. `FormatToolbarHook` handles toolbar button mousedown events and color picker. Both are separate from the existing `CommandPaletteHook`.

**Why**: Single responsibility. Each hook has a distinct concern. Merging would create a monolithic hook that's harder to test and maintain. Multiple hooks can coexist on the same or sibling elements.

### D4: Strip preference in Session struct (not LiveView assign)

The `strip_formatting` boolean lives in `Accounts.Session`, not as a bare LiveView assign. ChatLive reads it from `socket.assigns.session`.

**Why**: Session is the canonical location for per-user runtime state (Constitution IX). Other features may need to read the preference (e.g., notifications). Keeps LiveView thin (Constitution VII).

### D5: Format code limit enforced at display time (not send time)

The 128-code soft limit strips excess codes during rendering, not at message creation. The full message with all codes is stored in the database.

**Why**: Preserves data fidelity. If the limit is later raised, old messages render correctly. Display-time enforcement also means the sender's client doesn't need to count codes — the server handles it transparently.

### D6: No message schema change

Format codes are standard Unicode control characters (0x02–0x1F range) that the existing PostgreSQL `text` column stores without issue. No migration needed.

**Why**: Simplicity. Adding a separate "formatted_content" column or a "has_formatting" flag would be premature — the parser can detect format codes on the fly.

## Implementation Phases

### Phase A: Domain Foundation (Chat.Formatter + Policy)

**Goal**: Pure Elixir parser for mIRC format codes, with full test coverage.

1. **Chat.Formatter module** — `to_safe_html/1`, `strip/1`, `has_visible_text?/1`, `count_codes/1`
   - Internal state machine tracking bold/italic/underline/strikethrough/reverse/fg/bg
   - Color code parser: reads up to 2 digits for fg, optional comma + 2 digits for bg
   - HTML escaping of all text segments before span wrapping
   - 128-code soft limit (option `:max_codes`)
   - Tests: unit tests for every format code, combinations, edge cases, malformed input
   - Tests: StreamData property tests (strip then parse = no spans; parse preserves visible text)

2. **Chat.Policy extension** — `validate_content/1` updated to reject format-only messages
   - Uses `Formatter.has_visible_text?/1` after existing checks
   - Tests: format-only messages rejected, normal messages pass, mixed messages pass

3. **Accounts.Session extension** — `strip_formatting` field + `toggle_strip_formatting/1`
   - Tests: default false, toggle flips, struct typespec updated

### Phase B: CSS + Template Rendering

**Goal**: Formatted messages display correctly in the chat area.

4. **CSS classes** — Add `irc-bold`, `irc-italic`, `irc-underline`, `irc-strikethrough`, `irc-reverse-default`, `irc-fg-{0-15}`, `irc-bg-{0-15}` to dark-theme.css
   - Also add formatting toolbar and color picker styles

5. **ChatLive template update** — Replace `{msg.content}` with formatted output
   - For `:message` and `:action` types: call `Formatter.to_safe_html(msg.content)` (or `Formatter.strip(msg.content)` if `strip_formatting` is true)
   - For `:system`, `:service`, `:error` types: render as-is (no format parsing)
   - Add `strip_formatting` to socket assigns from session
   - Tests: LiveView tests verifying HTML output contains `irc-bold` class, color classes, etc.

### Phase C: Input — Keyboard Shortcuts

**Goal**: Users can insert format codes via keyboard shortcuts.

6. **FormatHook JS** — New hook for `#chat-input`
   - Intercept Ctrl+B/I/U/K/R/O keydown, preventDefault, insert control character at cursor
   - Register in app.js
   - Note: the input element already has `CommandPaletteHook`. FormatHook will be a separate hook on a wrapper element, or the two hooks will be merged registration (LiveView supports only one hook per element — need to compose them into a single hook or use a wrapper approach).

7. **Hook composition strategy** — Since LiveView allows only one `phx-hook` per element, either:
   - (a) Create a `ChatInputHook` that composes `CommandPaletteHook` + `FormatHook` logic, OR
   - (b) Attach `FormatHook` to a wrapper `<div>` around the input and use event delegation
   - Decision: Option (a) — merge into a single `ChatInputHook` that handles both command palette and formatting shortcuts. This is cleaner than event delegation and keeps all input behavior in one place.

### Phase D: Formatting Toolbar

**Goal**: Visual toolbar with B/I/U buttons and color picker dropdown.

8. **FormattingToolbar component** — Function component with B/I/U/Color buttons
   - Styled with 98.css conventions
   - Color picker: hidden dropdown toggled by Color button, 4x4 grid of swatches
   - `data-testid` attributes for E2E testing

9. **FormatToolbarHook JS** — Handles mousedown on toolbar buttons
   - Inserts format codes into `#chat-input` without stealing focus
   - Color picker: toggle dropdown, insert `\x03` + number on swatch click
   - Dismiss dropdown on outside click or Escape

10. **ChatLive integration** — Render `<.formatting_toolbar />` between messages and input form

### Phase E: Strip Formatting Toggle

**Goal**: Users can toggle format stripping on/off.

11. **ChatLive handler** — `handle_event("toggle_strip_formatting", ...)`
    - Toggles `session.strip_formatting` via `Session.toggle_strip_formatting/1`
    - Updates socket assigns
    - Re-renders all visible messages (stream reset or conditional class)

12. **UI control** — Add a toggle in the toolbar or menu bar
    - Checkbox-style button or menu item: "Strip Colors"

### Phase F: Integration & Polish

13. **Private messages** — Verify formatting works identically in PM view (should work automatically since the same template renders PMs)

14. **E2E tests** — Full flow tests: send formatted message → receive → verify rendering → toggle strip → verify plain

15. **Lint & dialyzer pass** — Ensure all new code has @spec, passes Credo strict, Dialyzer clean

## Complexity Tracking

> No constitution violations. Table intentionally left empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| — | — | — |

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| LiveView single-hook limitation (one phx-hook per element) | High | Medium | Merge CommandPaletteHook + FormatHook into one composed ChatInputHook |
| XSS via format parser producing unsafe HTML | Low | Critical | HTML-escape all user text before span wrapping; never interpolate raw user text into attributes |
| Browser Ctrl+B/I/U default actions interfere | Medium | Low | preventDefault() in hook keydown handler |
| Color picker dropdown positioning on small screens | Low | Low | Use `bottom: 100%` (opens upward above toolbar) with fallback |
| Existing tests break due to format codes in content | Low | Medium | Existing messages have no format codes; parser produces identical output for plain text |
