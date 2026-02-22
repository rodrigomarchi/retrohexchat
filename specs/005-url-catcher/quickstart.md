# Quickstart: URL Catcher (005)

**Branch**: `005-url-catcher` | **Date**: 2026-02-11

## Prerequisites

```bash
git checkout 005-url-catcher
make setup   # Ensure deps and DB are ready
make test    # Verify baseline (all tests pass)
make lint    # Verify baseline (all linters clean)
```

## New Dependencies

**None required.** `Req` (v0.5.17) and `Finch` (v0.21.0) are already in `mix.lock` as transitive dependencies. However, `Req` must be added as an explicit dependency in the domain app's `mix.exs` since it will be used directly for HTTP fetching.

```elixir
# apps/retro_hex_chat/mix.exs - add to deps
{:req, "~> 0.5"}
```

Then: `mix deps.get`

## New Modules (Domain Layer: `retro_hex_chat`)

| Module | Purpose | File |
|--------|---------|------|
| `Chat.URLDetector` | URL extraction & linkification (pure functions) | `lib/retro_hex_chat/chat/url_detector.ex` |
| `Chat.CapturedURL` | In-memory struct for captured URLs | `lib/retro_hex_chat/chat/captured_url.ex` |
| `Chat.LinkPreview` | Behaviour for title fetching | `lib/retro_hex_chat/chat/link_preview.ex` |
| `Chat.LinkPreview.HTTP` | Req-based implementation | `lib/retro_hex_chat/chat/link_preview/http.ex` |
| `Chat.LinkPreview.Cache` | ETS-based title cache | `lib/retro_hex_chat/chat/link_preview/cache.ex` |

## New Modules (Web Layer: `retro_hex_chat_web`)

| Module | Purpose | File |
|--------|---------|------|
| `Components.URLCatcherWindow` | retro design system floating window component | `lib/retro_hex_chat_web/components/url_catcher_window.ex` |

## New Assets

| File | Purpose |
|------|---------|
| `assets/js/hooks/url_catcher_hook.js` | Double-click to open URL in new tab |

## Modified Modules

| Module | Changes |
|--------|---------|
| `ChatLive` | URL extraction on message receipt, URL catcher assigns, `format_content/2` linkification, Alt+U shortcut, window toggle, link preview handle_info |
| `Components.MenuBar` | Add "URL Catcher" menu item |
| `Application` (domain) | Add `LinkPreview.Cache` and `Task.Supervisor` to supervision tree |

## No Migrations

This feature is entirely in-memory. No database changes required.

## Testing Strategy

| Test Type | What to Test |
|-----------|-------------|
| Unit | `URLDetector.extract_urls/1` — URL detection, boundary trimming, balanced parens |
| Unit | `URLDetector.linkify/1` — HTML output, truncation, escaping |
| Unit | `CapturedURL` — struct creation, filtering, sorting |
| Unit | `LinkPreview.HTTP.fetch_title/1` — title extraction, XSS escaping (with Mox) |
| Unit | `LinkPreview.Cache` — get/put, TTL, pending state |
| Property | `URLDetector.extract_urls/1` — random strings with embedded URLs |
| Integration | URL capture from channel messages in ChatLive |
| LiveView | URL Catcher window — open/close, sort, filter, search |
| LiveView | Clickable URLs in chat messages |
| LiveView | Link preview rendering |
| E2E | Full flow: send URL → see clickable link → open URL Catcher → filter → double-click |

## Key Test Commands

```bash
mix test                          # Full suite (excludes E2E)
mix test --only unit              # Unit tests only
mix test --only liveview          # LiveView tests only
mix test --only e2e               # E2E tests only
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/url_detector_test.exs  # Specific module
```

## Development Order

1. **Phase 1**: `URLDetector` (extract_urls, linkify) + tests
2. **Phase 2**: Linkification in ChatLive (`format_content` extension) + CSS + tests
3. **Phase 3**: `CapturedURL` + URL Catcher state + `URLCatcherWindow` component + Alt+U + tests
4. **Phase 4**: `LinkPreview` (behaviour, HTTP impl, cache, async fetch) + tests
5. **Phase 5**: E2E tests + edge cases + polish
