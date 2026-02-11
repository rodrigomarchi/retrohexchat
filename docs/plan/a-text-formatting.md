# Category A: Text Formatting & Colors

**Priority**: Red (High impact)
**Dependencies**: None (foundational)
**Existing**: A1 nick colors by hash already implemented

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| A1 | Nick colors by hash | Existing | Each nick gets a fixed color based on hash (~12 colors) |
| A2 | IRC inline colors (Ctrl+K) | New | mIRC color codes: foreground/background with 16 standard colors |
| A3 | Bold text (Ctrl+B) | New | Toggle bold in sent text, rendered for all users |
| A4 | Italic text (Ctrl+I) | New | Toggle italic in sent text |
| A5 | Underline text (Ctrl+U) | New | Toggle underline in text |
| A6 | Strikethrough text | New | Toggle strikethrough in text |
| A7 | Reverse text (Ctrl+R) | New | Invert foreground/background |
| A8 | Reset formatting (Ctrl+O) | New | Remove all formatting from cursor point onward |
| A9 | Strip codes option | New | Option to remove/ignore all formatting codes in received messages |
| A10 | Visual formatting toolbar | New | Toolbar above input with B/I/U/color buttons |

## Dependencies Detail

- A1 (existing) provides foundation for C3 (nick color overrides in Address Book)
- A9 (strip codes) relates to T7 (+c channel mode that strips colors)
- A2-A8 feed into V6 (color options in Options Dialog)

## Technical Notes (IRC/mIRC Reference)

- mIRC color codes use ASCII 3 (^C) + 0-15 for foreground, comma + 0-15 for background
- Standard 16 mIRC colors: white, black, navy, green, red, maroon, purple, orange, yellow, lime, teal, cyan, royal blue, magenta, gray, light gray
- Bold = ^B (0x02), Italic = ^] (0x1D), Underline = ^_ (0x1F), Strikethrough = ^~ (0x1E), Reverse = ^V (0x16), Reset = ^O (0x0F)
- In classic mIRC, formatted text codes are embedded in the raw message. Clients that don't support them show garbage characters unless they strip codes

---

## Spec Command

```
/speckit.specify "Text Formatting & Colors for RetroHexChat.

PROBLEM: Users currently have no way to express emphasis or visual style in their chat messages. In classic mIRC, rich text formatting (bold, italic, underline, colors) is a fundamental communication tool — users emphasize words, color-code information, and create visual distinction. Without this, the chat feels flat and lacks the expressive mIRC identity.

EXISTING CONTEXT: Nick colors by hash are already implemented — each nickname automatically gets a fixed color from ~12 options based on a hash of their name.

USER JOURNEY: A user chatting in a channel wants to emphasize a word. They press Ctrl+B before and after the word to make it bold. Another user sees the bold text rendered in the chat. A different user wants to add color — they press Ctrl+K, select a color number (0-15), and the subsequent text renders in that foreground color. They can also set a background color with Ctrl+K followed by foreground,background numbers. Italic (Ctrl+I), underline (Ctrl+U), strikethrough, and reverse video (Ctrl+R swaps foreground/background) work the same way. At any point, Ctrl+O resets all formatting back to plain text.

For users who find keyboard shortcuts difficult, a visual formatting toolbar sits above the input box with buttons for Bold, Italic, Underline, and a color picker grid showing the 16 standard mIRC colors. Clicking a toolbar button inserts the appropriate format code at the cursor position.

Some users prefer clean, unformatted text. A per-user 'Strip formatting codes' option, when enabled, removes all format codes from incoming messages and displays everything as plain text.

ACTORS: Any connected user (guest or registered) can send and receive formatted text. The strip-codes preference is per-user.

EDGE CASES: Malformed color codes (Ctrl+K with no number following) should render as plain text, not crash. Nested/overlapping format codes should degrade gracefully. Messages with only format codes and no visible text should not be sent. The formatting toolbar must not interfere with input focus or cursor position. Pasting text that contains mIRC format codes from external sources should render correctly.

SCOPE: In scope — all inline text formatting (bold, italic, underline, strikethrough, reverse, colors, reset), formatting toolbar, strip-codes option. Out of scope — custom color palettes beyond the 16 standard mIRC colors (that belongs in Options Dialog Cat V), channel-level forced color stripping (that belongs in Cat T as +c mode)."
```
