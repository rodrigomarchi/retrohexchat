# Category U: Options Dialog

**Priority**: Red (High impact — central configuration hub)
**Dependencies**: Aggregates settings from A, D, F, H, I, L, N, O, R, W
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| V1 | Complete Options dialog | New | Settings window organized in categories (like mIRC's Alt+O) |
| V2 | Connect options | New | Connection settings: reconnection, retry, timeouts |
| V3 | IRC messages options | New | Where to show: whois in active, notices in status, queries in window |
| V4 | Display options | New | Configure toolbar on/off, treebar on/off, switchbar on/off |
| V5 | Font options | New | Choose font and size for chat, UI, and each window type |
| V6 | Color options | New | Customize color palette: background, text, nick colors, system messages |
| V7 | Key bindings | New | Configure keyboard shortcuts |
| V8 | Line shading (alternating rows) | New | Alternating background on chat lines for readability |

## Dependencies Detail

- V is an **aggregator** — provides UI for settings from many categories
- Can be built incrementally: start with empty shell, add panels as categories ship
- V2 ← I (Perform) connection settings
- V3 ← L (Notices) routing, D (Highlights)
- V6 ← A (Text Formatting) color settings
- V7 ← standalone key binding system

## Technical Notes (IRC/mIRC Reference)

- mIRC Options (Alt+O): tree-view on left, settings panel on right
- Categories in mIRC: Connect, IRC, Sounds, Mouse, Highlight, Flood, Display, Colors, etc.
- mIRC options are saved to mirc.ini and persist across sessions
- Apply/OK/Cancel pattern: Apply saves without closing, OK saves and closes, Cancel discards
- Line shading: not in classic mIRC but present in HexChat and modern IRC clients

---

## Spec Command

```
/speckit.specify "Options Dialog for RetroHexChat.

PROBLEM: Users currently have no centralized place to configure the application. Preferences like font sizes, colors, message routing, keyboard shortcuts, and display toggles are either hardcoded or scattered. Classic mIRC provides a comprehensive Options dialog (Alt+O) as the single hub for all user preferences. This is the most impactful quality-of-life feature — it makes every other feature configurable.

USER JOURNEY: A user presses Alt+O (or selects Options from the menu). A retro-style dialog opens with a tree-view navigation panel on the left and a settings panel on the right. The tree shows categories: Connect, IRC Messages, Display, Fonts, Colors, Key Bindings. Clicking a category loads its settings panel.

CONNECT panel — Settings for auto-reconnect behavior: enable/disable, retry interval, maximum retries, connection timeout.

IRC MESSAGES panel — Configure where different message types are displayed: whois results (active window vs new window), notices (active window vs Status Window vs sender window), query/PM messages (new window vs active window). These routing preferences affect how the chat experience feels.

DISPLAY panel — Toggle visibility of UI elements: toolbar (on/off), treebar (on/off), switchbar (on/off), status bar (on/off). Toggle compact mode. These let users customize their workspace density.

FONTS panel — Select font family (from available monospace fonts) and size for: chat messages, input box, nicklist, treebar. A live preview shows how text will look with the selected settings before applying.

COLORS panel — Customize the color palette for: chat background, default text color, own messages, system messages, timestamps, error messages. A simple color picker grid (retro style, 16-24 preset colors plus custom) is provided. Users can also adjust the nick color palette here.

KEY BINDINGS panel — View and customize all keyboard shortcuts. Shows a list of actions with their current key binding. Click an action, then press a key combination to reassign it. A 'Reset to Defaults' button restores all original bindings.

LINE SHADING — A checkbox in the Display panel enables alternating row background colors in the chat area, making it easier to read long conversations. The shade intensity is subtly different (barely visible) to avoid visual noise.

All changes take effect immediately when 'Apply' is clicked. 'OK' applies and closes. 'Cancel' discards unsaved changes and closes.

ACTORS: Any connected user (guest or registered). Preferences persist across sessions for registered users; for guests, they persist for the current session.

EDGE CASES: Opening Options while another modal dialog is open should focus the existing dialog (prevent duplicates). Changing font size should immediately reflow the chat area without losing scroll position. Changing colors should update all open windows in real time. Invalid key bindings (binding two actions to the same key) should show a conflict warning. Resetting key bindings to defaults should require confirmation. If the user resizes the Options dialog, the tree-view and panel should scale appropriately.

NEGATIVE REQUIREMENTS: Options dialog must NOT block interaction with the chat (it should be modeless or have Apply without closing). Changing a setting must NOT require page reload. Key bindings must NOT be able to override browser-reserved shortcuts (Ctrl+W, Ctrl+T, etc.).

SCOPE: In scope — Options dialog shell with tree-view navigation, 6 settings panels (Connect, IRC Messages, Display, Fonts, Colors, Key Bindings), line shading toggle, Apply/OK/Cancel pattern, live preview for fonts. Out of scope — panels for features not yet implemented (those panels are added when their respective categories ship — this dialog is designed to be incrementally extended), import/export settings, settings sync between devices."
```
