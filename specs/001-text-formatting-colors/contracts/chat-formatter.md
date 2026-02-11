# Contract: Chat.Formatter

**Module**: `RetroHexChat.Chat.Formatter`
**Context**: `RetroHexChat.Chat`
**Purpose**: Parse mIRC format control codes and produce safe HTML or plain text.

## Public API

### `to_safe_html(content, opts \\ []) :: Phoenix.HTML.safe()`

Parses mIRC format control codes in `content` and returns a Phoenix HTML-safe value with `<span>` wrappers for formatted segments. All user text is HTML-escaped before wrapping.

**Options**:
- `:max_codes` — Maximum number of format codes to process (default: 128). Excess codes are stripped.

**Examples**:
```elixir
Formatter.to_safe_html("Hello \x02world\x02")
# => {:safe, "Hello <span class=\"irc-bold\">world</span>"}

Formatter.to_safe_html("\x034Red\x03 normal")
# => {:safe, "<span class=\"irc-fg-4\">Red</span> normal"}

Formatter.to_safe_html("\x034,1Red on black\x03")
# => {:safe, "<span class=\"irc-fg-4 irc-bg-1\">Red on black</span>"}

Formatter.to_safe_html("\x02\x1DHello\x0F world")
# => {:safe, "<span class=\"irc-bold irc-italic\">Hello</span> world"}
```

**Guarantees**:
- User text is always HTML-escaped (no XSS possible)
- Only `<span>` elements with `class` attributes are generated
- CSS classes follow pattern: `irc-bold`, `irc-italic`, `irc-underline`, `irc-strikethrough`, `irc-reverse`, `irc-fg-{0-15}`, `irc-bg-{0-15}`
- Empty input returns `{:safe, ""}`

---

### `strip(content) :: String.t()`

Removes all mIRC format control codes from `content`, returning plain text only.

**Examples**:
```elixir
Formatter.strip("\x02Bold\x02 and \x034colored\x03")
# => "Bold and colored"

Formatter.strip("\x03")
# => ""

Formatter.strip("\x0304Red\x03")
# => "Red"
```

**Guarantees**:
- All 7 control characters (0x02, 0x03, 0x0F, 0x16, 0x1D, 0x1E, 0x1F) are removed
- Color code digits and commas following 0x03 are also removed
- Visible text is preserved exactly as-is

---

### `visible_text(content) :: String.t()`

Alias for `strip/1`. Returns only the visible (non-control-code) text. Used for validation (empty message check).

---

### `has_visible_text?(content) :: boolean()`

Returns `true` if the content contains at least one non-whitespace visible character after stripping all format codes.

**Examples**:
```elixir
Formatter.has_visible_text?("\x02\x03")
# => false

Formatter.has_visible_text?("\x02Hello\x02")
# => true

Formatter.has_visible_text?("\x02  \x02")
# => false
```

---

### `count_codes(content) :: non_neg_integer()`

Counts the number of format control codes in the content. Used for the 128-code soft limit check.

**Examples**:
```elixir
Formatter.count_codes("\x02Bold\x02 \x1DItalic\x1D")
# => 4

Formatter.count_codes("\x034,1Colored\x03")
# => 2  # 0x03 opening + 0x03 closing
```
