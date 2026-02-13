# Category X: Smart Input & Command Help

**Priority**: Red (Critical — complements autocomplete for intelligent input)
**Dependencies**: W (Autocomplete System) for command context
**Existing**: X5 paste confirm dialog (paste_confirm_dialog.ex + paste_hook.js), X7 formatting toolbar (formatting_toolbar.ex + format_toolbar_hook.js), X8 char counter (char_counter_hook.js)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| X1 | Inline command syntax tooltip | New | While typing a command, show syntax and parameter descriptions above input (IDE-like); also shows brief hint after autocomplete selection |
| X2 | Parameter highlighting | New | Bold/highlight the parameter the user is currently filling in the syntax tooltip |
| X3 | Mode helper for /mode | New | After "/mode #canal +", show available modes with descriptions |
| X4 | Configurable detail level | New | Toggle in Settings: Beginner (full help) / Expert (syntax only) / Off |
| X5 | Multi-line paste detection | Existing | Dialog when pasting 3+ lines with Send All / Send 1-by-1 / Preview / Cancel |
| X6 | Contextual placeholder text | New | Input placeholder changes by context: "#general — / para comandos", "Mensagem para Mario", "Digite um comando" |
| X7 | Formatting toolbar | Existing | B/I/U/S/Color/Monospace buttons above input, 98.css styled |
| X8 | Character counter | Existing | Real-time counter showing current/max chars with color warnings |
| X9 | Input vertical expansion | New | Input grows up to 5 visible lines for long text, scroll after that |
| X10 | Enhanced history navigation | New | Ctrl+↑/↓ to navigate history without erasing current text, Ctrl+R for reverse search |
| X11 | History persistence | New | Persist last 100 commands/messages in localStorage across sessions |

## Dependencies Detail

- X1 (command syntax tooltip) activates after W's autocomplete selects a command — the tooltip shows syntax while the user fills parameters
- X5 (existing) provides multi-line paste infrastructure
- X7 (existing) provides formatting toolbar infrastructure
- X8 (existing) provides character counting infrastructure
- X6 (placeholder) depends on Chat context for current window type (channel, PM, status)
- X10 (Ctrl+R reverse search) is inspired by bash — shows inline search field within the input area
- X11 (history persistence) extends the existing input editbox history (already implemented in Feature 022)

## Technical Notes

- Existing paste_confirm_dialog.ex shows line count, flood warning, send/cancel options
- Existing paste_hook.js intercepts paste events with 2+ non-empty lines
- Existing formatting_toolbar.ex has B/I/U buttons + 4x4 IRC color picker, uses mousedown to preserve focus
- Existing char_counter_hook.js updates counter with warning/danger colors approaching 1000 char limit
- Command syntax tooltip should appear above the input (like IDE parameter hints), not overlap with autocomplete dropdown
- The tooltip activates in two ways: (1) after autocomplete selection completes, (2) when user types a known command manually
- The tooltip updates in real-time as the user types, highlighting the current parameter position
- Input expansion: use CSS resize + max-height with overflow-y: auto after 5 lines
- History persistence: store in localStorage keyed by user, load on mount
- Ctrl+R reverse search: inline search field appears within input area, filters history as user types

---

## Spec Command

```
/speckit.specify "Smart Input & Command Help for RetroHexChat.

PROBLEM: The chat input is currently a basic text field that provides no guidance while typing commands. Users must memorize command syntax, have no visual feedback about parameters, and cannot see what a command expects. After selecting a command from the autocomplete (Category W), there is no follow-up guidance about the command's parameters. The input also lacks modern conveniences: it does not expand for multi-line text, has no contextual placeholder, and history navigation is basic (cannot browse history without losing current text). These gaps make the input feel primitive compared to both modern chat apps and even classic mIRC.

EXISTING CONTEXT: Three input enhancements are already implemented. (1) Paste confirm dialog (paste_confirm_dialog.ex + paste_hook.js) intercepts multi-line paste and shows a confirmation dialog with line count. (2) Formatting toolbar (formatting_toolbar.ex + format_toolbar_hook.js) provides B/I/U buttons and a 16-color IRC color picker above the input. (3) Character counter (char_counter_hook.js) shows real-time character count with warning colors. Input editbox history (Up/Down arrows) is also already implemented.

USER JOURNEY — COMMAND SYNTAX HELP: A user selects '/mode' from the autocomplete dropdown. Immediately after selection, a syntax tooltip appears above the input showing: '/mode <#canal> <+/-modos> [nick]'. As they type '/mode #general +o', the tooltip updates — the [nick] parameter is now highlighted in bold, indicating it is the next expected argument. Below the syntax line, available modes are listed: '+o nick — Dar operador, +v nick — Dar voz, +b mask — Banir'. The tooltip says 'Você está definindo: +o (operador). Próximo: nickname do usuário.' The user can press Esc to dismiss it. If the user types a command directly (without using autocomplete), the tooltip also appears once the command is recognized. In Settings, they can set the detail level: Beginner shows full descriptions and examples, Expert shows only the syntax line, Off disables the tooltip entirely.

USER JOURNEY — SMART INPUT: A user opens a channel. The input placeholder reads 'Mensagem para #general — / para comandos'. They switch to a PM with Mario — the placeholder changes to 'Mensagem para Mario — / para comandos'. In the Status window, it reads 'Digite um comando — / para lista'. When they start typing a long message, the input grows vertically up to 5 lines, then shows a scrollbar. The character counter (already implemented) updates in real-time.

USER JOURNEY — ENHANCED HISTORY: A user has typed half a message but wants to check what they sent earlier. They press Ctrl+Up — the input saves their current text and shows the previous history entry. Ctrl+Down returns to their draft. Regular Up/Down in an empty input works as before. They press Ctrl+R — an inline search field appears. They type 'join' and it shows the most recent history entry containing 'join'. Their command history persists across sessions — when they reload the page, the last 100 entries are available.

ACTORS: Any connected user (guest or registered). Syntax tooltip detail level and history are per-user preferences.

EDGE CASES: The syntax tooltip must not overlap with the autocomplete dropdown — if autocomplete is open, the tooltip waits until a command is selected. If the command is unknown, the tooltip should not appear. The input expansion must not push the chat messages area off screen — it should compress the chat area above. Ctrl+R search with no matches should show 'No match' inline. History persistence must handle localStorage being full gracefully (drop oldest entries). Placeholder text must update immediately on channel switch, not with a delay.

NEGATIVE REQUIREMENTS: The syntax tooltip must NOT block the chat view — it appears in a small area above the input. The tooltip must NOT appear for regular messages (only after /). Input expansion must NOT exceed 5 visible lines before scrolling. History persistence must NOT store passwords or sensitive command arguments (/identify, /nickserv).

SCOPE: In scope — inline command syntax tooltip with parameter highlighting (activating both after autocomplete selection and on manual command typing), mode helper for /mode, configurable detail level (Beginner/Expert/Off), contextual placeholder text, input vertical expansion up to 5 lines, Ctrl+Up/Down history navigation preserving current text, Ctrl+R reverse history search, localStorage history persistence (100 entries). Out of scope — spell-checking, grammar suggestions, message drafts per channel, input themes/styling beyond 98.css."
```
