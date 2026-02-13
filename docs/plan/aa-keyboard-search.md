# Category AA: Keyboard Shortcuts & Chat Search

**Priority**: Red (Critical — keyboard-driven power user features)
**Dependencies**: None (foundational keyboard infrastructure)
**Existing**: AA1 keyboard hook (keyboard_hook.js), AA8 search bar (search_bar.ex)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AA1 | Keyboard hook | Existing | LiveView hook handling Arrow Up/Down for history and Tab for nick completion |
| AA2 | Global shortcut system | New | Centralized shortcut registry with web-safe key combos (Ctrl+Shift+Key pattern) |
| AA3 | Shortcut cheatsheet dialog | New | Ctrl+/ opens 98.css dialog listing all shortcuts organized by category |
| AA4 | Navigation shortcuts | New | Ctrl+Tab / Ctrl+Shift+Tab for window cycling, Alt+1..9 for window N |
| AA5 | Channel navigation | New | Alt+↑/↓ to navigate between channels in treebar |
| AA6 | System shortcuts | New | Alt+O (Options), Alt+B (Address Book), Alt+R (Script Editor), F1 (Help), F5 (Refresh channel list) |
| AA7 | Customizable shortcuts | New | Settings dialog where users can rebind keyboard shortcuts |
| AA8 | Search bar component | Existing | Win98-styled search dialog with input, Find Next/Prev, "X of Y" counter |
| AA9 | Search highlight in chat | New | Matching text in chat messages highlighted with yellow background |
| AA10 | Search result navigation | New | ↑↓ arrows in search bar navigate between matches, scrolling chat to each result |
| AA11 | Search filters | New | Checkboxes: Case-sensitive, Regex, Only my nick (messages mentioning me) |
| AA12 | Search in message history | New | Option to search beyond loaded messages into database history |

## Dependencies Detail

- AA1 (existing) provides the base keyboard hook infrastructure for all shortcut handling
- AA2 (global shortcut system) extends keyboard_hook.js into a centralized registry
- AA3 (cheatsheet) is self-contained UI, displays registered shortcuts
- AA4-AA6 implement specific shortcut actions using the registry
- AA8 (existing) provides the search UI component and basic Find functionality
- AA9-AA12 extend search_bar.ex with highlighting, navigation, and filters
- AA12 (history search) depends on H (Logging System) for database message retrieval

## Technical Notes

- Existing keyboard_hook.js handles Arrow Up/Down for command history and Tab for nick completion
- Existing search_bar.ex renders a Win98-styled search dialog with text input, Find Next/Prev buttons, and "X of Y" counter
- Global shortcuts must use web-safe combinations — Ctrl+Shift+Key pattern avoids browser conflicts
- Many shortcuts already implemented in Feature 022: Ctrl+Shift+F (search), Ctrl+Shift+B (bold), etc.
- Cheatsheet dialog: organized by category (Navigation, Chat, Formatting, System) in a scrollable 98.css window
- Search highlighting: use CSS class on matching text spans, yellow background with smooth transitions
- Search result navigation: maintain array of match positions, scroll to nth match on ↑↓
- Regex search: use JavaScript RegExp with error handling for invalid patterns
- History search option: when enabled, makes a database query via the Logging/Chat context

---

## Spec Command

```
/speckit.specify "Keyboard Shortcuts & Chat Search for RetroHexChat.

PROBLEM: While basic keyboard handling exists (history navigation, Tab completion, some Ctrl+Shift shortcuts), there is no centralized shortcut system, no cheatsheet for users to discover available shortcuts, and no way to customize key bindings. The search feature has a basic bar component but lacks result highlighting in the chat, navigation between matches, and advanced filters. Power users who prefer keyboard-driven workflows cannot efficiently navigate windows, switch channels, or access dialogs without the mouse.

EXISTING CONTEXT: (1) keyboard_hook.js handles Arrow Up/Down for command history navigation and Tab for nick completion in the chat input. (2) search_bar.ex provides a Win98-styled search dialog with text input, Find Next/Previous buttons, and an 'X of Y' result counter. (3) Several keyboard shortcuts already exist from Feature 022: Ctrl+Shift+F (search), Ctrl+Shift+B (bold), Ctrl+Shift+I (italic), Ctrl+Shift+U (underline), Ctrl+Shift+K (color), Ctrl+Shift+L (clear), Ctrl+Shift+M (mute). These use the web-safe Ctrl+Shift+Key pattern to avoid browser shortcut conflicts.

USER JOURNEY — KEYBOARD SHORTCUTS: A new user presses Ctrl+/ (or Ctrl+Shift+/) to see what shortcuts are available. A 98.css-styled dialog opens with shortcuts organized by category: Navigation (Ctrl+Tab for next window, Ctrl+Shift+Tab for previous, Alt+1..9 for window N, Alt+↑/↓ for treebar navigation), Chat (↑/↓ for history, Tab for autocomplete, Ctrl+Shift+F for search, Ctrl+Shift+L for clear), Formatting (Ctrl+Shift+B/I/U/K), System (Alt+O for Options, Alt+B for Address Book, F1 for Help, F5 for Refresh channels). They close the dialog and press Ctrl+Tab — the focus switches to the next channel. Alt+1 takes them to the first window. Alt+↓ moves down the treebar.

A power user opens Settings and navigates to the Keyboard Shortcuts section. They see a list of all shortcuts with their current bindings. They click on a shortcut and press a new key combination to rebind it. Conflicts are detected and shown as warnings.

USER JOURNEY — CHAT SEARCH: A user presses Ctrl+Shift+F. The search bar appears above the chat area. They type 'terraform' — all occurrences of 'terraform' in the visible chat are highlighted with a yellow background. The counter shows '3/17' (viewing 3rd of 17 results). They press ↓ in the search bar — the chat scrolls to the next match and the counter updates to '4/17'. They check 'Case-sensitive' to narrow results. They check 'Regex' and type 'error|warn' to find both errors and warnings. They check 'Only my nick' to see only messages that mentioned them. They toggle 'Search history' to extend the search into the database beyond currently loaded messages. Pressing Esc closes the search bar and removes all highlights.

ACTORS: All keyboard shortcuts are available to any connected user (guest or registered). Custom keybindings persist for registered users. Search is available to any user in any channel or PM.

EDGE CASES: Keyboard shortcuts must not fire when the user is typing in a text input (except navigation shortcuts like Ctrl+Tab). If the user presses a shortcut that conflicts with the browser (e.g., Ctrl+W to close tab), the browser behavior should win — use only web-safe combinations. Invalid regex in search should show an inline error message, not crash. Searching in a channel with thousands of messages should not freeze the UI — use incremental search with a debounce. Alt+N shortcuts for windows 1-9 must handle the case where fewer than N windows exist (do nothing). The search bar should remember the last search term when reopened in the same session.

NEGATIVE REQUIREMENTS: Keyboard shortcuts must NOT override essential browser shortcuts (Ctrl+T, Ctrl+W, Ctrl+N, Ctrl+L, F5 browser refresh — use our F5 only when input is focused). The cheatsheet dialog must NOT be editable — it is read-only. Search must NOT modify or filter messages — it only highlights them. Custom shortcut bindings must NOT allow binding to single letter keys (would break typing).

SCOPE: In scope — centralized shortcut registry, cheatsheet dialog (Ctrl+/), navigation shortcuts (Ctrl+Tab, Alt+1..9, Alt+↑↓), system shortcuts (Alt+O, Alt+B, F1, F5), customizable keybindings in Settings, search highlighting with yellow background, search result navigation with ↑↓, search filters (case-sensitive, regex, only-my-nick), search in database history. Out of scope — vim-style keybindings, macro recording, search and replace, search across multiple channels simultaneously."
```
