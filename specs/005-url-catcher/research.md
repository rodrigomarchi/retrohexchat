# Research: URL Catcher (005)

**Branch**: `005-url-catcher` | **Date**: 2026-02-11

## R1: URL Detection Approach

**Decision**: Create a standalone `Chat.URLDetector` module in the domain layer with a robust regex-based URL extractor that handles boundary detection (trailing punctuation, balanced parentheses).

**Rationale**: The existing `Highlight` module already has `@url_pattern ~r{https?://\S+}i` which is too greedy (includes trailing punctuation). A dedicated module with a refined regex and post-processing for boundary trimming provides:
- Reusability (highlight masking, linkification, URL catcher all share it)
- Testability (pure function, property-based tests)
- Correctness (handles edge cases the simple regex misses)

**Alternatives considered**:
- **Linkify hex package**: External dependency, less control over edge cases, adds a dep for something achievable with a well-tested regex.
- **Extend Highlight.mask_urls**: Wrong responsibility — Highlight masks URLs to prevent false matches; URL detection is a distinct concern.
- **Post-process HTML output**: Fragile — URLs can span format-code boundaries in the HTML, making regex replacement on HTML unreliable.

## R2: URL Linkification Integration Point

**Decision**: Extend `format_content/2` in ChatLive to call a new `URLDetector.linkify_html/1` function that processes the Formatter's HTML output, replacing URL text with `<a>` tags. For the `strip_formatting=true` path, call `URLDetector.linkify/1` on stripped+escaped text.

**Rationale**: The Formatter generates HTML with `<span>` elements for IRC formatting. URL linkification is a display concern that should layer on top of formatting, not be mixed into the Formatter's IRC-code parsing logic. Processing at the `format_content` level keeps the Formatter single-responsibility and makes the linkification opt-in.

**Alternatives considered**:
- **Modify `Formatter.to_safe_html` directly**: Mixes two concerns (IRC formatting + URL detection). The Formatter's job is IRC codes → HTML spans, not URL detection.
- **Client-side JavaScript linkification**: Violates Constitution I (zero JS UI frameworks). Would require a JS hook to regex-replace URLs in rendered HTML, which is fragile with LiveView DOM patching.
- **Pre-process URLs before Formatter**: Would need to inject placeholder tokens, then replace after formatting — over-engineered for the common case.

## R3: URL Catcher State Management

**Decision**: Store URL catcher entries directly in socket assigns (`@url_catcher_entries`) as a list of `CapturedURL` structs. No Session struct extension, no database persistence.

**Rationale**: The spec explicitly states URL catcher data is per-session and resets on reconnect. This is purely UI state — it doesn't need to survive NickServ identify, be shared across processes, or be persisted. Socket assigns are the simplest correct location. The existing pattern of `@show_notify_list` / `@show_address_book` assigns proves this works well for window state.

**Alternatives considered**:
- **Add to Session struct**: Overcomplicates Session with transient UI state. Session fields (notify_list, contacts, etc.) all have persistence paths — URL catcher intentionally does not.
- **Separate GenServer per user**: Over-engineered for a per-LiveView-process list that doesn't need cross-process access.
- **ETS table keyed by user**: Unnecessary — the data is scoped to a single LiveView process.

## R4: Link Preview HTTP Client

**Decision**: Use `Req` (already in mix.lock at v0.5.17) for HTTP title fetching via a `Chat.LinkPreview` behaviour with an HTTP implementation module. Add `Finch` pool to the domain app's supervision tree (Req uses Finch internally).

**Rationale**: Req is already a transitive dependency (via Phoenix/Swoosh), provides a simple API (`Req.get/2`), handles redirects natively, and supports timeouts. A behaviour interface enables Mox-based testing per Constitution V. Finch pool provides connection reuse for repeated fetches.

**Alternatives considered**:
- **Finch directly**: Lower-level API, more boilerplate for simple GET requests. Req wraps Finch with sane defaults.
- **HTTPoison/Tesla**: Not in deps, would add unnecessary dependencies when Req is already available.
- **No HTTP client (JS-only fetch)**: Violates Constitution I (LiveView-only) and creates CORS issues.

## R5: Link Preview Cache Strategy

**Decision**: Use an ETS table (`Chat.LinkPreview.Cache`) for per-node title caching with a 1-hour TTL. The cache is started in the domain app's supervision tree.

**Rationale**: Per Constitution IX, hot runtime data should live in ETS. Title fetches are expensive (HTTP round-trip) and the same URL appears frequently in chat. ETS provides O(1) lookups, automatic cleanup via periodic sweep, and survives individual process crashes. 1-hour TTL balances freshness with fetch reduction.

**Alternatives considered**:
- **Process dictionary**: Dies with the LiveView process, no sharing.
- **Agent**: Single-process bottleneck for concurrent lookups.
- **Cachex**: External dependency for a simple key-value cache.
- **No cache**: Every URL appearance triggers an HTTP fetch — wasteful and slow.

## R6: Keyboard Shortcut

**Decision**: `Alt+U` for the URL Catcher window.

**Rationale**: Follows the established `Alt+letter` pattern. Existing shortcuts: `Alt+B` (Address Book), `Alt+H` (Highlight Dialog), `Ctrl+F` (Search). `Alt+U` is mnemonic for "URL" and has no conflict.

**Alternatives considered**:
- `Alt+L` (for "Links"): Less intuitive than `Alt+U` for "URL".
- `Alt+C` (for "Catcher"): Could conflict with future Copy shortcut.

## R7: URL Catcher Window Style

**Decision**: Floating window (like NotifyListWindow), not a centered dialog. Position: bottom-right area, z-index 150.

**Rationale**: The URL Catcher is a reference window users keep open while chatting, similar to the Notify List. Floating windows can be left open alongside chat. Centered dialogs (like Address Book, Highlight Dialog) are for configuration tasks that block other interaction. The URL Catcher is read-mostly with occasional interaction (filter, search, double-click).

**Alternatives considered**:
- **Centered dialog**: Would block chat interaction when open, poor UX for a reference window.
- **Sidebar panel**: Would require layout changes to the MDI structure.

## R8: Async Title Fetch Architecture

**Decision**: Use `Task.Supervisor` in the domain app's supervision tree. ChatLive spawns tasks via `Task.Supervisor.async_nolink/2` for each URL. Results are sent back to the LiveView process via `send(self(), {:link_preview, url, title})`.

**Rationale**: `Task.Supervisor` provides fault isolation (a failed fetch doesn't crash the LiveView), automatic cleanup, and follows OTP conventions. `async_nolink` ensures the LiveView isn't linked to fetch tasks (a timeout/crash in the fetch doesn't take down the LiveView). The LiveView handles `:link_preview` messages to update both chat display and URL catcher entries.

**Alternatives considered**:
- **Task.async**: Links to the calling process — a fetch crash would crash the LiveView.
- **GenServer pool**: Over-engineered for fire-and-forget title fetches.
- **PubSub broadcast**: Unnecessary indirection — only one LiveView process cares about each fetch result.

## R9: URL Detection Regex Design

**Decision**: Two-phase approach: (1) Greedy regex `~r{https?://[^\s<>]+}i` to find URL candidates, (2) Post-processing to trim trailing punctuation and handle balanced parentheses.

**Rationale**: No single regex can correctly handle all URL boundary cases (trailing periods, balanced parens in Wikipedia links, closing brackets). A greedy match followed by trim handles:
- Trailing `.`, `,`, `!`, `?`, `)` (when unbalanced), `]`, `:`
- Balanced `()` in Wikipedia URLs: `https://en.wikipedia.org/wiki/Elixir_(programming_language)`
- Query strings and fragments: `?key=val&key2=val2#anchor`

**Alternatives considered**:
- **Single complex regex**: Unmaintainable and still misses edge cases.
- **URI.parse/1**: Too permissive (accepts any scheme), doesn't handle boundary detection.
- **Existing `@url_pattern`**: `~r{https?://\S+}i` is too greedy (includes trailing punctuation in the match).
