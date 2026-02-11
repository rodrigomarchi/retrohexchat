# Research: Text Formatting & Colors

**Feature Branch**: `001-text-formatting-colors`
**Date**: 2026-02-11

## R1: mIRC Format Code Specification

**Decision**: Use the standard mIRC control code set as defined by the IRC client convention.

**Control Codes**:

| Code | Hex  | Name          | Behavior                                                    |
|------|------|---------------|-------------------------------------------------------------|
| 0x02 | \x02 | Bold          | Toggle bold on/off                                          |
| 0x03 | \x03 | Color         | Followed by optional `N` or `N,M` (fg, bg). Bare = reset   |
| 0x0F | \x0F | Reset         | Clears all formatting (bold, italic, underline, color, etc) |
| 0x16 | \x16 | Reverse       | Toggle foreground/background swap                           |
| 0x1D | \x1D | Italic        | Toggle italic on/off                                        |
| 0x1E | \x1E | Strikethrough | Toggle strikethrough on/off                                 |
| 0x1F | \x1F | Underline     | Toggle underline on/off                                     |

**Color Code Parsing Rules** (after 0x03):
- Read up to 2 digits for foreground (0–15, optionally zero-padded: "04" = 4)
- If followed by `,`, read up to 2 digits for background
- If no digits follow, reset color to default
- Numbers > 15 are not valid color codes; only the valid prefix is consumed (e.g., "16" → color 1 + literal "6")

**Rationale**: This is the de facto standard used by mIRC, HexChat, WeeChat, and most IRC clients. Using the same codes ensures compatibility with any future IRC bridging.

**Alternatives considered**:
- ANSI escape codes — rejected, not standard for IRC
- Custom markdown-like syntax — rejected, not mIRC-compatible
- HTML tags — rejected, security risk and not mIRC-compatible

## R2: Server-Side vs Client-Side Parsing

**Decision**: Server-side parsing in Elixir. The `Chat.Formatter` module parses mIRC control codes and produces Phoenix-safe HTML (using `Phoenix.HTML.raw/1`).

**Rationale**:
- Parsing in Elixir keeps the logic testable with ExUnit (Constitution IV: TDD)
- Avoids JavaScript UI framework logic (Constitution I: zero JS frameworks)
- HTML sanitization is controlled server-side, preventing XSS
- LiveView's server rendering model means the formatted HTML is sent as part of the diff
- Stripping (for the strip-codes preference) also happens server-side, keeping it a simple conditional in the template

**Alternatives considered**:
- Client-side JS parsing — rejected, violates Constitution I (minimal JS hooks only), harder to test, XSS surface
- Storing pre-rendered HTML — rejected, prevents strip-codes preference from working per-user

## R3: XSS Prevention Strategy

**Decision**: The formatter MUST HTML-escape all user text content FIRST, then wrap formatted segments in `<span>` tags with CSS classes. Never interpolate raw user text into HTML attributes.

**Approach**:
1. Split content into segments by control codes
2. HTML-escape each text segment via `Phoenix.HTML.html_escape/1`
3. Wrap segments in `<span class="irc-bold irc-color-4">` etc.
4. Combine into a Phoenix.HTML safe tuple
5. Render with `raw()` in the template — safe because all user text was escaped

**Rationale**: HTML-escaping before wrapping ensures no user-supplied content can inject tags or attributes. The `<span>` wrappers use CSS classes only (no inline `style` from user input).

**Alternatives considered**:
- Using `content_tag` per segment — possible but verbose for inline spans
- Using data attributes + JS rendering — violates Constitution I

## R4: Keyboard Shortcut Implementation

**Decision**: A new JavaScript hook (`FormatHook`) attached to the chat input captures Ctrl+B/I/U/K/R/O keydown events, inserts the corresponding Unicode control character at the cursor position, and prevents the browser's default action.

**Rationale**:
- Constitution VII allows "keyboard shortcuts only" as valid JS hook scope
- Must intercept before browser defaults (Ctrl+B = browser bold, Ctrl+I = browser italic, Ctrl+U = browser underline, Ctrl+K = browser address bar in some browsers)
- The hook inserts raw control characters directly into the input value — no server roundtrip needed for input manipulation
- For Ctrl+K specifically: inserts 0x03 character; the user then types the color number as regular digits

**Alternatives considered**:
- Handling in LiveView via phx-keydown — rejected, too much latency for character insertion; would require server roundtrip per keystroke
- Extending CommandPaletteHook — rejected, different concerns; formatting hook should be separate and composable

## R5: Formatting Toolbar Component Architecture

**Decision**: A new `FormattingToolbar` function component rendered above the input form in ChatLive. Toolbar button clicks are handled by a companion JS hook (`FormatToolbarHook`) that inserts codes without stealing focus.

**Approach**:
- The toolbar is a pure presentation component with `phx-click` events that are intercepted by the JS hook before reaching the server
- The hook captures `mousedown` (not `click`) on toolbar buttons to prevent input blur
- On mousedown: reads cursor position from input, inserts code, restores focus and cursor
- Color picker dropdown: a hidden div toggled by the Color button, positioned absolutely below the button, closed on outside click or Escape

**Rationale**: Using `mousedown` + `preventDefault()` prevents the input from losing focus. This pattern is standard for formatting toolbars (same approach as TinyMCE, Quill, etc.). Keeping it as a JS hook aligns with Constitution VII (minimal JS for keyboard/UI interaction).

**Alternatives considered**:
- Server-side phx-click handling — rejected, would cause input to lose focus during server roundtrip
- Separate LiveComponent — rejected, unnecessary complexity for a stateless toolbar

## R6: Strip Formatting Codes Preference

**Decision**: Add a `strip_formatting` boolean field to the `Accounts.Session` struct. Default: `false`. Toggle via a UI control (menu or toolbar button). The ChatLive template conditionally calls `Formatter.strip/1` or `Formatter.to_safe_html/1` based on this flag.

**Rationale**:
- Session struct is the natural place for per-user runtime preferences (Constitution IX: hot data in memory)
- No database persistence needed per spec — resets on reconnect
- Conditional rendering in the template keeps the logic in the view layer where it belongs

**Alternatives considered**:
- LiveView assign without Session — possible but Session is the canonical place for user state
- Database-persisted preference — out of scope per spec

## R7: Empty Message Validation

**Decision**: Extend `Chat.Policy.validate_content/1` to strip mIRC control codes before checking for empty content. A message that is only control codes (no visible text after stripping) is rejected.

**Rationale**:
- The validation already exists — just needs to also consider control-code-only messages as "empty"
- Stripping for validation uses the same `Formatter.strip/1` function used for the display preference
- This keeps validation in the Policy module where it belongs (Constitution II: bounded contexts)

**Alternatives considered**:
- Validating in ChatLive — rejected, business logic belongs in domain layer
- Validating in Channels.Server — rejected, Policy module is the correct location
