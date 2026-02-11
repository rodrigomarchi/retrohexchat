# Contract: Chat.URLDetector

**Module**: `RetroHexChat.Chat.URLDetector`
**Layer**: Domain (`retro_hex_chat`)
**Dependencies**: None (pure functions)

## Public API

### `extract_urls/1`

Extracts all URLs from raw message text, returning them in order of appearance.

```elixir
@spec extract_urls(String.t()) :: [String.t()]
```

**Input**: Raw message content (may contain IRC format codes).
**Output**: List of URL strings, in order of appearance. Empty list if no URLs found.

**Behavior**:
- Detects `http://` and `https://` URLs
- Strips IRC format codes before detection (uses `Formatter.strip/1`)
- Trims trailing punctuation: `.` `,` `!` `?` `:` `;`
- Handles balanced parentheses: `(` in URL keeps matching `)`, unbalanced `)` is trimmed
- Handles balanced brackets: `[` in URL keeps matching `]`, unbalanced `]` is trimmed
- Does NOT detect bare domains (e.g., `example.com`)
- Returns the raw URL string (not HTML-escaped)

**Examples**:
```elixir
extract_urls("check https://example.com out")
#=> ["https://example.com"]

extract_urls("visit https://example.com.")
#=> ["https://example.com"]

extract_urls("see https://en.wikipedia.org/wiki/Elixir_(programming_language)")
#=> ["https://en.wikipedia.org/wiki/Elixir_(programming_language)"]

extract_urls("links: https://a.com and https://b.com")
#=> ["https://a.com", "https://b.com"]

extract_urls("no urls here")
#=> []
```

### `linkify/1`

Converts plain text to HTML with URLs wrapped in `<a>` tags. Non-URL text is HTML-escaped.

```elixir
@spec linkify(String.t()) :: String.t()
```

**Input**: Plain text (already stripped of IRC format codes).
**Output**: HTML string where URLs are wrapped in `<a>` tags and all other text is HTML-escaped.

**Behavior**:
- URLs get: `<a href="URL" target="_blank" rel="noopener noreferrer" class="chat-link" title="FULL_URL">DISPLAY_TEXT</a>`
- URLs > 100 chars: display text is truncated to 100 chars + "..."
- Non-URL text is HTML-escaped via `Phoenix.HTML.html_escape/1`
- Multiple URLs in one text are each independently linkified

### `linkify_html/1`

Post-processes Formatter HTML output to wrap URL text in `<a>` tags. Handles URLs that may span `<span>` boundaries.

```elixir
@spec linkify_html(String.t()) :: String.t()
```

**Input**: HTML string from `Formatter.to_safe_html/1` (contains `<span>` elements with IRC formatting classes).
**Output**: HTML string with URL text additionally wrapped in `<a>` tags.

**Behavior**:
- Detects URL text within and across `<span>` elements
- Wraps URL text in `<a>` tags with same attributes as `linkify/1`
- Preserves existing `<span>` formatting (bold, color, etc.) around/within the link
- Long URL display text is truncated
- Non-URL content is unchanged
