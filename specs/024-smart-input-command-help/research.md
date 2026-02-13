# Research: Smart Input & Command Help

**Feature**: 024-smart-input-command-help
**Date**: 2026-02-13

## R1: Command Syntax Data Extraction

**Decision**: Parse structured syntax definitions from the existing `Handler.help/0` callback return values at compile time, using the existing `Registry.command_metadata/0` pattern.

**Rationale**: Every command handler already implements `help/0` returning `%{name, syntax, description, examples}`. The syntax strings follow a consistent convention: `<required>` and `[optional]` parameters. The Registry already calls `help/0` at compile time to build metadata. Adding a new `syntax_definition/0` callback to the Handler behaviour would provide machine-readable parameter definitions alongside the existing human-readable syntax string.

**Alternatives considered**:
- **Parse syntax strings at runtime**: Fragile — relies on string convention consistency across 47 handlers. Regex parsing of `<param>` and `[param]` patterns works but can't distinguish parameter types (nick vs. channel vs. text) without additional annotation.
- **Add structured metadata to each handler**: Chosen — a new optional callback `syntax_definition/0` returns a list of parameter structs. The Registry aggregates these at compile time. Handlers that don't implement it fall back to displaying the raw syntax string.
- **External configuration file**: Rejected — separates parameter data from handler code, increasing maintenance burden. Violates the constitution's one-module-per-command principle.

## R2: Tooltip Visibility Coordination with Autocomplete

**Decision**: Use shared state in the AutocompleteHook to track autocomplete dropdown visibility. The tooltip renders/hides based on a LiveView assign (`show_syntax_tooltip`) that the server controls, coordinated with `show_autocomplete` assign.

**Rationale**: The autocomplete dropdown visibility is already tracked server-side via `show_autocomplete` assign and client-side via `dropdownVisible` in the hook. The syntax tooltip can use the inverse condition: visible when `show_autocomplete == false` AND input starts with a recognized command. The server evaluates tooltip content on each input change event that's already being sent for autocomplete detection.

**Alternatives considered**:
- **Pure client-side tooltip**: Rejected — would require duplicating the command registry data in JavaScript. The server already has all metadata and can efficiently compute tooltip content.
- **Hybrid approach (chosen)**: Server computes tooltip content and sends it via `push_event`. Client renders/positions the tooltip DOM. This follows the existing autocomplete pattern (server fuzzy-matches, client renders dropdown).

## R3: Input Element — `<input>` to `<textarea>` Conversion

**Decision**: Replace the `<input type="text">` with a `<textarea>` element to support multi-line expansion.

**Rationale**: HTML `<input type="text">` cannot grow vertically — it is inherently single-line. A `<textarea>` with CSS `resize: none` and dynamic height calculation (via JavaScript) achieves the 5-line expansion requirement. The textarea must submit on Enter (not newline), with Shift+Enter for explicit newlines — matching modern chat conventions.

**Alternatives considered**:
- **Keep `<input>` with overflow**: Not possible — `<input>` cannot display multiple lines.
- **contenteditable div**: Rejected — introduces complexity with cursor management, formatting persistence, and LiveView value binding. The `<textarea>` is simpler, works with standard form submission, and integrates naturally with existing hooks.
- **Textarea (chosen)**: Standard HTML element, supports `rows` attribute, works with existing `maxlength`, and can be height-managed via JavaScript. Requires updating hooks that reference `this.el` or `#chat-input` to handle textarea behavior (Enter vs. newline).

**Impact**: The `<input>` → `<textarea>` change affects:
1. `autocomplete_hook.js` — Enter key handling (submit vs. newline)
2. `char_counter_hook.js` — No change (reads `.value` same as input)
3. `paste_hook.js` — No change (reads paste event same way)
4. `format_toolbar_hook.js` — `insertAtCursor` uses `selectionStart`/`selectionEnd` which work identically on textarea
5. `chat_live.html.heex` — Element change from `<input>` to `<textarea>`
6. `core_events.ex` — No change (receives form values via `send_input`)
7. CSS — Textarea needs explicit styling to match current input appearance

## R4: History Architecture — Client-Side vs. Server-Side

**Decision**: Implement enhanced history (Ctrl+Up/Down, Ctrl+R, persistence) entirely client-side in a new JavaScript hook, coexisting with the existing server-side history.

**Rationale**: The existing history uses server-side state (`command_history` list, `history_index` integer) in LiveView assigns, navigated via `pushEvent("history_navigate")`. The enhanced history needs: (1) draft preservation (purely client-side concern), (2) localStorage persistence (client-side by definition), (3) reverse search UI (client-side rendering). Building this client-side avoids round-trips for every keystroke and keeps persistent storage local.

**Coexistence strategy**:
- **Existing Up/Down in empty input**: Continues using server-side `history_navigate` event (no change).
- **New Ctrl+Up/Down**: Handled client-side in the hook, using localStorage-backed history. Does NOT push events to server.
- **New Ctrl+R**: Entirely client-side — search, display, and selection all happen in the hook.
- **History sync**: When a message is sent (via server `send_input` event), the hook also appends to its client-side history before the server processes it.

**Alternatives considered**:
- **Fully server-side**: Rejected — would require database persistence for guest users (overengineering), round-trips for every Ctrl+Up/Down press (latency), and doesn't solve localStorage persistence.
- **Replace server-side history**: Rejected — existing Up/Down behavior is working and tested. Replacing it risks regression. Coexistence is safer.
- **Hybrid (chosen)**: Best of both worlds — server-side for existing behavior, client-side for new features.

## R5: Tooltip Detail Level Preference Storage

**Decision**: Add `command_help_level` to the existing `display` preferences category with values `:beginner`, `:expert`, `:off`.

**Rationale**: The `display` category already holds UI behavior preferences (toolbar visibility, compact mode, timestamp format). Command help detail level is a UI display concern. Adding one key to an existing category avoids schema changes — the preferences system uses a JSON column that accommodates new keys without migration.

**Alternatives considered**:
- **New preference category**: Rejected — overkill for a single preference. Constitution says "simplicity MUST be the default."
- **localStorage setting**: Rejected — wouldn't persist for registered users across devices. The existing preference system already handles persistence.
- **Display category (chosen)**: Natural fit, minimal code change, works with existing save/load pipeline.

## R6: Sensitive Command Detection for History

**Decision**: Maintain a static list of sensitive command prefixes (`/identify`, `/nickserv`, `/ns`) and filter them before localStorage persistence. Do NOT filter from the in-session history buffer.

**Rationale**: The sensitive commands are well-known and finite (NickServ-related). A static list is simpler and more predictable than heuristic password detection. Commands are filtered only at the persistence boundary — they remain in the in-session buffer so users can recall them with Up/Down during their current session.

**Alternatives considered**:
- **Regex-based password detection**: Rejected — too fragile, false positives on legitimate messages.
- **Per-handler `sensitive` flag**: Over-engineered — only 2-3 commands are sensitive. A static list is clearer.
- **Static list (chosen)**: Simple, auditable, easy to extend.

## R7: textarea Submission Behavior

**Decision**: Enter submits the form (sends the message). Shift+Enter inserts a newline in the textarea. This matches modern chat application conventions (Discord, Slack, Telegram).

**Rationale**: Users expect Enter to send in a chat application. The existing `<input>` submits on Enter via the form. Switching to `<textarea>` changes the default behavior (Enter inserts newline), so we must intercept Enter in JavaScript and trigger form submission programmatically.

**Alternatives considered**:
- **Enter = newline, button = send**: Rejected — breaks muscle memory, inconsistent with virtually all chat apps.
- **Enter = send, Shift+Enter = newline (chosen)**: Industry standard, matches user expectations.
