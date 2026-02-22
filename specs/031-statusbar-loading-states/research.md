# Research: Status Bar & Loading States

**Feature**: 031-statusbar-loading-states
**Date**: 2026-02-15

## R1: Ping/Pong Latency Measurement in Phoenix LiveView

**Decision**: Use LiveView's built-in channel for ping/pong. The JS hook sends a `pushEvent("ping", {client_time: Date.now()})` every 30 seconds. The server `handle_event("pong", ...)` echoes the timestamp back via `push_event("pong", %{client_time: ...})`. The client calculates `Date.now() - client_time` for the round-trip.

**Rationale**: LiveView already maintains a persistent WebSocket connection. Using `pushEvent`/`push_event` reuses the existing channel with zero additional connections. This is the same transport path users experience, so the measurement reflects real user-perceived latency.

**Alternatives considered**:
- **Separate WebSocket for ping**: Adds connection overhead, measures a different path than LiveView traffic. Rejected.
- **HTTP endpoint ping**: Doesn't reflect WebSocket latency. Different transport. Rejected.
- **Phoenix.Channel heartbeat**: The built-in heartbeat is internal to the framework and not easily observable from hooks. Rejected.

## R2: Connection State Detection in LiveView Hooks

**Decision**: Use Phoenix LiveView's lifecycle callbacks in JS hooks: `connected()` method returns current state. Listen for `phx:page-loading-start` and `phx:page-loading-stop` window events. The `ReconnectHook` already uses `MutationObserver` on `phx-loading` class — the new `ConnectionBannerHook` will use the same pattern but with debounce logic.

**Rationale**: LiveView exposes connection state through the `phx-loading` class on the root element and through hook lifecycle methods (`mounted`, `disconnected`, `reconnected`). These are the official, stable APIs.

**Alternatives considered**:
- **Custom WebSocket state polling**: Accessing `liveSocket.socket` internals. Fragile, relies on private API. Rejected.
- **Server-side connection tracking with process monitoring**: Overly complex for per-session state. Rejected.

## R3: Banner vs Overlay Coexistence Strategy

**Decision**: The connection banner operates on a 1-second debounce timer. When a disconnection is detected, a 1-second timer starts. If the connection recovers within 1 second, no banner is shown. If it persists beyond 1 second, the banner appears. The existing `ReconnectHook` overlay has its own activation logic (watches `phx-loading` class with its countdown). When the overlay becomes visible (detected via its DOM element or a shared flag in `window`), the banner hides itself.

**Rationale**: Two independent mechanisms need coordination. The banner is the "light" feedback (1-10s disconnections), the overlay is the "heavy" feedback (extended disconnections). Using a simple visibility check on the overlay DOM element avoids tight coupling.

**Alternatives considered**:
- **Merge banner into reconnect hook**: Would make the reconnect hook much more complex. The two have different UI patterns (inline banner vs full overlay). Rejected.
- **Shared state manager**: Over-engineering for two components. Rejected.

## R4: Clock Implementation

**Decision**: Pure client-side. A `ClockHook` uses `setInterval` every 30 seconds (not 60 — to avoid worst-case 59-second staleness at mount time) to format `new Date()` as `HH:MM` using `toLocaleTimeString` with `hour: '2-digit', minute: '2-digit', hour12: false` options. Updates the DOM element directly.

**Rationale**: The clock is purely cosmetic local-time display. No server involvement needed. `toLocaleTimeString` handles timezone automatically.

**Alternatives considered**:
- **Server-side time broadcast**: Adds unnecessary server load for information the client already has. Rejected.
- **Update every second**: Not needed for HH:MM display, wastes CPU. Rejected.

## R5: Channel History Loading State

**Decision**: Add a `loading_channel` assign to `ChatLive`. When `join_channel` is called, set `loading_channel: channel_name` before the DB query. After messages are streamed, set `loading_channel: nil`. The template conditionally renders a `loading_spinner` component when `@loading_channel` is set and no messages exist for the current channel. For rapid switching, each `join_channel` call overwrites `loading_channel`, and the previous channel's messages are naturally replaced by the stream reset.

**Rationale**: The existing `join_channel` helper already does the work synchronously in the LiveView process. Adding an assign before/after the operation is the simplest approach. Since LiveView processes messages sequentially, there's no race condition — the most recent `join_channel` call always wins.

**Alternatives considered**:
- **Async Task for channel loading**: Would add complexity (Task.async, handle_info for result). The current synchronous approach is fast enough (50 message limit). Rejected for now — can be added later if DB queries become slow.
- **Client-side loading detection**: Hooks watching for empty message containers. Fragile, depends on DOM timing. Rejected.

## R6: Channel List Loading Progress

**Decision**: Add a `loading_channels` boolean assign to `ChannelListLive`. Since `Autocomplete.list_visible_channels` loads all channels synchronously in `mount/3`, the loading state is only visible during the initial mount. Use `assign_async` or a simple `send(self(), :load_channels)` pattern to make the load non-blocking, showing a progress bar in the meantime. The count updates as channels arrive.

**Rationale**: Currently `mount/3` loads all channels synchronously, which blocks the first render. Moving to an async pattern lets the UI render immediately with a loading indicator.

**Alternatives considered**:
- **Keep synchronous with spinner**: Would still block initial render — the spinner wouldn't be visible because mount hasn't completed. Rejected.
- **Streaming channels in batches**: Over-engineering — the channel list is typically small (hundreds, not thousands). A single async load is sufficient. Rejected.

## R7: Connection Progress Steps

**Decision**: Use a client-side state machine in `ConnectionProgressHook` that tracks conceptual connection steps. Step 1 ("Resolving...") starts immediately on mount. Step 2 ("Connecting...") starts when the LiveView socket begins connecting (detected via `phx:page-loading-start`). Step 3 ("Waiting for response...") starts when the WebSocket is open but LiveView hasn't mounted yet. All steps complete when the hook's `mounted()` callback fires. The progress indicator lives in `ConnectLive` (the login page) rather than `ChatLive`.

**Rationale**: The actual connection steps (DNS, TCP, TLS, WebSocket upgrade) are handled by the browser and aren't individually observable from JavaScript. The steps are conceptual/decorative, giving users visual progress during what would otherwise be a blank screen.

**Alternatives considered**:
- **Real network timing via PerformanceObserver**: Too complex, browser support varies, DNS/TCP aren't separately observable for WebSocket connections. Rejected.
- **Server-sent progress events**: The server can't send events before the connection is established — circular dependency. Rejected.

## R8: Status Bar Layout Strategy

**Decision**: Restructure the status bar into 3 logical sections using CSS flexbox:
- **Left**: Channel name + user count (existing, unchanged)
- **Center**: Connection state indicator with colored icon
- **Right**: Lag display + clock (pipe-separated)

Use fixed minimum widths for the lag and clock fields to prevent layout shifts when values change (e.g., "Lag: 45ms" vs "Lag: 250ms"). The mute toggle moves to the right section or becomes a small icon.

**Rationale**: The current status bar has 5 separate `status-bar-field` elements with no grouping. The retro design system `.status-bar` uses flexbox. Grouping into 3 sections matches the IRC-style status bar layout described in the spec.

**Alternatives considered**:
- **Keep flat 5-field layout and add more fields**: Would be too crowded and hard to scan. Rejected.
- **Two-row status bar**: Breaks the retro aesthetic (single-row status bar). Rejected.
