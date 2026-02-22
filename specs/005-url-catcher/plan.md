# Implementation Plan: URL Catcher

**Branch**: `005-url-catcher` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-url-catcher/spec.md`

## Summary

URL Catcher adds three capabilities to RetroHexChat: (1) automatic URL detection and clickable link rendering in chat messages, (2) a URL Catcher floating window that aggregates all URLs shared in the user's channels/PMs with sort/filter/search, and (3) asynchronous inline link previews showing page titles. All data is in-memory (per-session, no DB persistence). The URL detection engine lives in the domain layer as pure functions; the URL Catcher window follows the existing retro MDI floating window pattern; link previews use Req for HTTP fetching with ETS-based caching.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, retro design system, Req 0.5+ (HTTP client, already in mix.lock)
**Storage**: In-memory only (socket assigns + ETS cache). No PostgreSQL changes.
**Testing**: ExUnit, Mox (for LinkPreview behaviour), StreamData (property-based URL detection), Floki (HTML assertions)
**Target Platform**: Web browser (Phoenix LiveView)
**Project Type**: Umbrella (retro_hex_chat domain + retro_hex_chat_web)
**Performance Goals**: URL detection adds no perceptible delay to message rendering; link preview titles appear within 5 seconds
**Constraints**: Zero JavaScript UI frameworks (Constitution I); link previews must not block rendering; XSS prevention on external page titles
**Scale/Scope**: URL Catcher window responsive with up to 500 entries; link preview cache per-node

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Elixir & Phoenix Exclusive** | PASS | All logic in Elixir. URL detection is pure functions. HTTP fetching uses Req (Elixir). No JS UI frameworks. |
| **II. Umbrella with Bounded Contexts** | PASS | URLDetector, CapturedURL, LinkPreview in `Chat` context (domain). URLCatcherWindow component in web layer. ChatLive stays thin. |
| **III. OTP Process Architecture** | PASS | LinkPreview.Cache as ETS table (supervised). Task.Supervisor for async fetches. No new GenServers needed. |
| **IV. Test-First Development** | PASS | Unit tests for URLDetector (pure functions + property-based). Mox for LinkPreview. LiveView tests for window & rendering. E2E tests. |
| **V. Contracts and Behaviours** | PASS | `Chat.LinkPreview` behaviour with `fetch_title/1` callback. HTTP implementation module. Mox-testable. |
| **VI. Static Analysis** | PASS | `@spec` on all public functions. Credo strict. Dialyxir. mix format. |
| **VII. Lean LiveViews** | PASS | URL detection logic in domain `Chat.URLDetector`. Filtering/sorting in domain `CapturedURL`. ChatLive delegates to domain functions. |
| **VIII. retro Fidelity** | PASS | URLCatcherWindow uses retro CSS classes. Floating window matches NotifyListWindow pattern. Link styling fits retro aesthetic. |
| **IX. Hot/Cold Data Separation** | PASS | All URL Catcher data is hot (in-memory). Link preview cache in ETS. No PostgreSQL persistence needed (spec requirement). |
| **X. Scalable Architecture** | PASS | ETS cache is per-node (scales with clustering). Task.Supervisor handles concurrent fetches. No architectural dead-ends. |

**Gate result: ALL PASS. No violations.**

## Project Structure

### Documentation (this feature)

```text
specs/005-url-catcher/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 research decisions
├── data-model.md        # In-memory data model
├── quickstart.md        # Development quickstart guide
├── contracts/
│   ├── url_detector.md  # URLDetector API contract
│   ├── link_preview.md  # LinkPreview behaviour contract
│   ├── captured_url.md  # CapturedURL struct contract
│   └── url_catcher_window.md  # Window component contract
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/chat/
│   ├── url_detector.ex          # URL extraction & linkification
│   ├── captured_url.ex          # In-memory URL entry struct
│   ├── link_preview.ex          # Behaviour definition
│   └── link_preview/
│       ├── http.ex              # Req-based implementation
│       └── cache.ex             # ETS-based title cache
└── test/retro_hex_chat/chat/
    ├── url_detector_test.exs    # Unit + property tests
    ├── captured_url_test.exs    # Unit tests
    └── link_preview/
        ├── http_test.exs        # Unit tests (Mox)
        └── cache_test.exs       # Unit tests

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── url_catcher_window.ex  # retro design system floating window
│   └── live/
│       └── chat_live.ex           # Modified: linkification, catcher state, previews
├── assets/js/hooks/
│   └── url_catcher_hook.js        # Double-click handler
└── test/retro_hex_chat_web/live/
    └── chat_live_url_catcher_test.exs  # LiveView tests
```

**Structure Decision**: Follows existing umbrella structure. New modules go in the `Chat` bounded context since URL detection/linkification is a chat message concern. No new bounded context needed.

## Implementation Phases

### Phase 1: URL Detection Engine (Domain Layer)

**Goal**: Pure-function URL extraction with robust boundary detection.

**Modules**:
- `Chat.URLDetector` — `extract_urls/1`, `linkify/1`, `linkify_html/1`

**Key design decisions**:
- Two-phase detection: greedy regex `~r{https?://[^\s<>]+}i` → post-process trim
- Trailing punctuation trimming: `.` `,` `!` `?` `:` `;` `)`(unbalanced) `]`(unbalanced)
- Balanced parentheses: count `(` vs `)` in URL, trim excess closing parens
- IRC format codes: strip before detection via `Formatter.strip/1`
- Truncation: URLs > 100 chars display as first 100 chars + "..."
- HTML output: `<a href="URL" target="_blank" rel="noopener noreferrer" class="chat-link" title="FULL_URL">DISPLAY</a>`

**Tests**: Unit tests for all edge cases (trailing punctuation, balanced parens, multiple URLs, format codes, empty input). Property-based tests for invariants (extracted URLs are valid, linkified output is valid HTML).

### Phase 2: Clickable URLs in Chat (Web Layer)

**Goal**: URLs in chat messages render as clickable links.

**Changes**:
- Extend `format_content/2` in ChatLive to call `URLDetector.linkify/1` (stripped path) or `URLDetector.linkify_html/1` (formatted path)
- Add CSS classes: `.chat-link` (underline, distinct color, cursor pointer)
- CSS for long URL truncation: `max-width` with `text-overflow: ellipsis` on inline display (or handled in `linkify` output)

**Key design decisions**:
- Linkification happens at render time in `format_content/2`, not at message storage time
- Links open in new tab with `rel="noopener noreferrer"` for security
- Link color fits retro aesthetic (blue, underlined — classic web link style)

**Tests**: LiveView tests for clickable link rendering, multiple URLs, trailing punctuation exclusion, long URL truncation, format code interaction.

### Phase 3: URL Catcher State & Window (Domain + Web)

**Goal**: URL Catcher window showing all captured URLs with sort/filter/search.

**Domain modules**:
- `Chat.CapturedURL` — struct + filtering/sorting utilities

**Web changes**:
- `ChatLive`: New assigns (`url_catcher_entries`, `show_url_catcher`, `url_catcher_sort_column`, `url_catcher_sort_direction`, `url_catcher_filter_channel`, `url_catcher_search_query`)
- URL extraction in `handle_info` for `:new_message` — extract URLs, create `CapturedURL` entries, append to assigns
- `Components.URLCatcherWindow` — floating window component (retro design system)
- `Components.MenuBar` — add "URL Catcher" item
- `Alt+U` keyboard shortcut
- `URLCatcherHook` JS — double-click opens URL in new tab

**Key design decisions**:
- URLs captured from both channel messages and PMs
- Filtering/sorting done in assigns (no streams needed — max 500 entries is small)
- Channel filter dropdown built from unique sources in captured entries
- Real-time: new URLs added to assigns in `handle_info`, component re-renders automatically
- Window follows NotifyListWindow pattern (floating, absolute position, z-index 150)

**Tests**: Unit tests for CapturedURL filtering/sorting. LiveView tests for window open/close, sort, filter, search, real-time updates, menu bar item, keyboard shortcut.

### Phase 4: Link Preview (Domain + Web)

**Goal**: Asynchronous page title fetching and display.

**Domain modules**:
- `Chat.LinkPreview` — behaviour (`fetch_title/1` callback)
- `Chat.LinkPreview.HTTP` — Req-based implementation
- `Chat.LinkPreview.Cache` — ETS-based cache with TTL

**Supervision tree changes**:
- Add `Chat.LinkPreview.Cache` to domain app supervision tree
- Add `{Task.Supervisor, name: RetroHexChat.LinkPreviewTasks}` to domain app supervision tree

**Web changes**:
- ChatLive: On new message with URL, check cache → if miss, spawn async fetch task
- ChatLive: `handle_info({:link_preview, url, result})` — update message preview in stream, update CapturedURL entry
- Template: Render preview title below link text (small, muted text)

**Key design decisions**:
- `Task.Supervisor.async_nolink` for fault isolation
- Cache check before fetch (dedup concurrent requests via `pending?` flag)
- 5-second timeout per fetch
- Only fetch for first 50KB of response (avoid downloading large files)
- Title HTML-escaped to prevent XSS
- Preview rendered as `<span class="chat-link-preview">Title</span>` below the link
- No preview shown on error (graceful degradation)

**Tests**: Unit tests for title extraction, HTML escaping, cache TTL, error handling. Mox tests for HTTP behaviour. LiveView tests for async preview rendering, timeout handling.

### Phase 5: E2E Tests & Polish

**Goal**: End-to-end test coverage and edge case handling.

**E2E tests**:
- Send URL → see clickable link → click opens new tab
- Multiple URLs in one message
- URL with trailing punctuation
- URL Catcher window: open, filter, search, sort, double-click
- Link preview appears asynchronously
- Session reset: reconnect clears URL Catcher

**Polish**:
- `data-testid` attributes on all interactive elements
- Edge cases: URLs in system/service/error messages (not linkified — only user messages)
- Edge case: URL in `/me` action messages
- Verify URL detection works with all IRC format codes
- Verify long URL truncation visual appearance

## Complexity Tracking

> No violations to justify — all Constitution principles pass.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | — | — |
