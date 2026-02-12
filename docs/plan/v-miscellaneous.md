# Category V: Miscellaneous / Polish

**Priority**: Mixed (W7/W8/W14 are Red; others are Yellow/Green)
**Dependencies**: M for W5 (finger reply)
**Existing**: W9 input editbox history already implemented

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| W1 | About dialog | New | "Help -> About" with credits, version, pixelated Windows 98 style logo |
| W2 | IRC commands reference | New | "Help -> IRC Commands" with complete reference accessible within the app |
| W3 | Keyboard shortcuts reference | New | Dialog listing all available keyboard shortcuts |
| W4 | Customizable quit message | New | Configure the message displayed when doing /quit |
| W5 | Customizable finger reply | New | Configure the /ctcp finger response |
| W6 | Away with auto-reply | New | When someone PMs you while away, auto-reply with your away message |
| W7 | Double-click actions | New | Double-click nick -> open query. Double-click channel -> join. Double-click URL -> open |
| W8 | Right-click copy | New | Select text in chat and copy via right-click or Ctrl+C |
| W9 | Input editbox history | Existing | Up/Down arrows to navigate command history |
| W10 | Multi-line paste dialog | New | When pasting multi-line text, dialog asks: "Paste X lines?" |
| W11 | Character counter | New | Character counter in input showing IRC 512-char limit |
| W12 | Emoji/Emoticon support | New | Unicode emoji support in chat with optional picker |
| W13 | Timestamp format options | New | Configure timestamp format: [HH:MM], [HH:MM:SS], etc. |
| W14 | Nick column alignment | New | Align nicknames in a fixed column so all messages start at same position |

## Dependencies Detail

- W5 (finger reply) depends on M (CTCP)
- W6 (away auto-reply) uses existing /away infrastructure
- W7 (double-click) depends on E1 (URL detection) for URL double-click
- W13 (timestamp format) integrates into U (Options Dialog)
- Most W items are independent

## Internal Priority

- **Red (High)**: W7 (double-click actions), W8 (right-click copy), W14 (nick column alignment)
- **Yellow (Medium)**: W4 (quit message), W6 (away auto-reply), W10 (multi-line paste), W11 (char counter)
- **Green (Low)**: W1 (about), W2 (commands ref), W3 (shortcuts ref), W5 (finger), W12 (emoji), W13 (timestamp format)

## Technical Notes (IRC/mIRC Reference)

- mIRC About: Help > About, shows version, registration info, credits
- mIRC double-click: configurable per element type (nick, channel, URL, word)
- mIRC quit message: default "Leaving" but configurable via Options or /quit [message]
- mIRC finger reply: configurable in Tools > Options > IRC > CTCP
- mIRC multi-line paste: warns before sending multiple lines (prevents accidental flood)
- mIRC character limit follows IRC protocol: 512 bytes per message including protocol overhead
- Nick column alignment: common in HexChat and irssi (fixed-width nick column)
- Emoji picker is a modern feature not in classic mIRC

---

## Spec Command

```
/speckit.specify "Miscellaneous / Polish for RetroHexChat.

PROBLEM: The application lacks many small but important polish features that make the difference between a functional chat client and a pleasant one. Users cannot copy text from the chat, cannot double-click to interact with elements, have no help references, cannot customize quit messages, have no character count feedback, and messages are not visually aligned. These polish items collectively have a significant impact on daily usability.

EXISTING CONTEXT: Input editbox history (W9) is already implemented — Up/Down arrows navigate command history.

USER JOURNEYS:

DOUBLE-CLICK ACTIONS (Red priority): A user double-clicks a nickname in the nicklist — a PM query window opens. They double-click a channel name mentioned in chat — they join that channel. They double-click a URL — it opens in a new tab. Double-click behavior is intuitive and consistent across all clickable elements.

RIGHT-CLICK COPY (Red priority): A user selects text in the chat area by clicking and dragging. They right-click and see a context menu with 'Copy'. Clicking it copies the selected text to the clipboard. Ctrl+C also works for copying selected text.

NICK COLUMN ALIGNMENT (Red priority): All nicknames in the chat are rendered in a fixed-width column. Whether the nick is 3 characters or 15, all message text starts at the same horizontal position. This dramatically improves readability in busy channels. The column width adjusts to the longest visible nick or can be set to a fixed width.

ABOUT DIALOG: Help > About opens a Windows 98-style dialog showing: application name (RetroHexChat), version number, credits, and a pixelated retro logo.

IRC COMMANDS REFERENCE: Help > IRC Commands opens a scrollable dialog with a complete reference of all available slash commands, their syntax, parameters, and examples.

KEYBOARD SHORTCUTS REFERENCE: Help > Keyboard Shortcuts opens a dialog organized by category (navigation, formatting, commands) listing all key bindings.

QUIT MESSAGE: Users can configure a custom quit message shown to others when they disconnect. Set via preferences or '/quit Goodbye everyone!'. Default: 'Leaving'.

FINGER REPLY: Users can configure their CTCP FINGER response text (requires CTCP from Cat M to be implemented).

AWAY AUTO-REPLY: When a user is /away and someone sends them a PM, the system automatically replies once with their away message: '* UserNick is away: Gone for lunch'. The auto-reply is sent only once per unique sender until the user returns (prevents spam).

MULTI-LINE PASTE DIALOG: When a user pastes text containing multiple lines into the input, a confirmation dialog appears: 'You are about to send N lines. Send all as separate messages / Cancel'. This prevents accidental flooding.

CHARACTER COUNTER: A real-time character counter appears near the input box showing current/maximum (e.g., '127/512'). The counter changes color as the user approaches the limit (e.g., turns red above 450 characters).

EMOJI SUPPORT: Unicode emojis are rendered properly in chat messages. An optional emoji picker popup (grid of common emojis by category) is accessible via a small toolbar button. Clicking an emoji inserts it at the cursor position.

TIMESTAMP FORMAT: Users can configure the timestamp format for chat messages: [HH:MM] (default), [HH:MM:SS], [DD/MM HH:MM], or no timestamps. Setting available in Options Dialog.

ACTORS: All features available to any connected user (guest or registered). Preferences persist for registered users.

EDGE CASES: Double-clicking an offline user in a /whowas list should not attempt to open a PM (show 'user is offline'). Right-click copy with no text selected should show a disabled 'Copy' option. Pasting more than 50 lines should warn about potential flood even more strongly. Character counter should account for Unicode characters that may take multiple bytes. Very wide nicknames (max 16 chars) should not break the nick column alignment layout. Emoji picker should be dismissable by clicking outside it or pressing Escape.

NEGATIVE REQUIREMENTS: Away auto-reply must NOT respond to notices (per IRC convention). Away auto-reply must NOT respond to the same sender more than once per away session. Multi-line paste must NOT send lines without user confirmation.

SCOPE: In scope — all 13 new items listed above. Out of scope — custom double-click action configuration (fixed behavior only), rich text clipboard (copy as plain text only)."
```
