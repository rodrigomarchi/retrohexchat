# Category E: URL Catcher

**Priority**: Red (High impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| E1 | Automatic URL detection | New | Links in chat are detected and made clickable (opens in new tab) |
| E2 | URL Catcher list | New | All URLs mentioned in chat are captured and stored in a dedicated list |
| E3 | URL list window | New | Dedicated window listing all captured URLs with metadata |
| E4 | Inline link preview | New | Basic preview (page title) shown alongside the link in chat |

## Dependencies Detail

- E is fully independent — no dependencies on other categories
- E1 (clickable URLs) is foundational for W7 (double-click actions on URLs)

## Technical Notes (IRC/mIRC Reference)

- mIRC auto-detects URLs and renders them as clickable links (underlined, different color)
- The URL Catcher (Tools > URL Catcher) stores all seen URLs with channel, nick, and timestamp
- mIRC uses a configurable regex for URL detection
- Link preview is a modern addition not present in classic mIRC but common in modern chat clients (Slack, Discord)

---

## Spec Command

```
/speckit.specify "URL Catcher for RetroHexChat.

PROBLEM: When users share links in chat, the URLs appear as plain text — they are not clickable and quickly scroll away into history. Users have no way to find a link someone shared 20 minutes ago without scrolling through hundreds of messages. This is a fundamental usability gap for any chat application.

USER JOURNEY: A user in #elixir shares a link: 'check this out https://hexdocs.pm/phoenix'. The URL is automatically detected, rendered as a clickable link (underlined, distinct color), and opens in a new browser tab when clicked. Below or beside the link, a small preview appears showing the page title fetched from the linked page (e.g., 'Phoenix Framework — Overview').

Later, another user who missed the link opens the URL Catcher window (via menu or toolbar). This window shows a sortable list of all URLs shared across all channels and PMs the user is in, with columns: URL, Channel, Posted By, Time. They can filter by channel or search by URL text. Double-clicking an entry opens the URL in a new tab.

ACTORS: Any connected user (guest or registered) can see clickable URLs and access the URL Catcher. The URL Catcher is per-session — it captures URLs from the moment the user connects.

EDGE CASES: URLs with special characters, query parameters, and fragments must be detected correctly. URLs at the end of a sentence followed by punctuation (e.g., 'visit https://example.com.') must not include the trailing period. Very long URLs should be visually truncated in the chat but link to the full URL. Link preview fetching must not block message rendering — previews appear asynchronously. If the linked page cannot be reached or has no title, no preview is shown (graceful degradation). Malicious URLs should not be able to inject content into the chat via the preview title.

NEGATIVE REQUIREMENTS: The URL catcher must NOT persist across sessions (it resets on reconnect). Link previews must NOT execute scripts or render HTML from external pages — only plain text titles are displayed.

SCOPE: In scope — URL auto-detection and clickable rendering, URL Catcher window with filtering and search, inline link preview (page title only). Out of scope — link preview thumbnails or rich embeds (images, videos), URL shortener resolution, link safety/malware scanning."
```
